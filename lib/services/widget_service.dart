import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_cache_store.dart';
import '../data/auth_session_store.dart';
import '../data/memorial_store.dart';
import '../data/pet_avatar_store.dart';
import '../utils/pet_display_image.dart';

/// iOS 主屏幕小组件：由原生写入 App Group（JSON + PNG）
class WidgetService {
  WidgetService._();

  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel(
    'com.example.flutterPetMemorial/widget',
  );

  Future<void>? _syncChain;

  Future<void> updateWidget({int retries = 5}) {
    _syncChain = (_syncChain ?? Future<void>.value()).then(
      (_) => _updateWidgetWithRetries(retries),
    );
    return _syncChain!;
  }

  Future<void> _updateWidgetWithRetries(int retries) async {
    if (!Platform.isIOS) return;

    AppCacheStore.instance.repairLocalPetImage();
    await PetAvatarStore.ensureLocalCacheForWidget(
      petId: AppCacheStore.instance.petId,
    );

    Object? lastError;
    for (var attempt = 0; attempt < retries; attempt++) {
      try {
        final ok = await _updateWidgetOnce();
        if (ok) return;
      } catch (e, st) {
        lastError = e;
        debugPrint('[WidgetService] attempt ${attempt + 1} failed: $e\n$st');
      }
      if (attempt < retries - 1) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    if (lastError != null) {
      debugPrint('[WidgetService] all retries failed: $lastError');
    }
  }

  Future<bool> _updateWidgetOnce() async {
    if (!await _waitForNativeChannel()) {
      debugPrint('[WidgetService] native channel not ready');
      return false;
    }

    final cache = AppCacheStore.instance;
    final profile = cache.petProfile;
    final memorials = MemorialStore.instance.items;
    final petId = cache.petId;

    final petName =
        profile?['nickname']?.toString().trim() ??
        profile?['name']?.toString().trim() ??
        '';
    final petType =
        profile?['type']?.toString() ?? profile?['pet_type']?.toString() ?? '';
    final petAge = '${cache.accompanyDays}';

    final imageCandidates = await PetDisplayImage.downloadCandidates();
    final petImageUrl = imageCandidates.isNotEmpty ? imageCandidates.first : '';

    final localImagePath = await _prepareWidgetImagePath(
      imageCandidates,
      petId: petId,
    );

    final imageBytes = localImagePath == null
        ? await _loadRemoteImageBytes(imageCandidates)
        : null;
    final imageBase64 = imageBytes != null && imageBytes.isNotEmpty
        ? base64Encode(imageBytes)
        : '';

    final memorialPayload = memorials
        .take(10)
        .map(
          (day) => {
            'id': day.id,
            'title': day.title,
            'days': '${day.displayDayCount}',
            'status': day.statusLabel,
          },
        )
        .toList();

    final token = AuthSessionStore.instance.token;
    final result = await _channel
        .invokeMethod<Map<Object?, Object?>>('syncWidget', {
          'petId': '${petId ?? ''}',
          'petName': petName,
          'petType': petType,
          'petAge': petAge,
          'petImageUrl': petImageUrl,
          'memorials': jsonEncode(memorialPayload),
          'localImagePath': localImagePath ?? '',
          'imageBase64':
              localImagePath == null && imageBase64.length <= 4 * 1024 * 1024
              ? imageBase64
              : '',
          'authToken': token ?? '',
        });

    final imageWritten = result?['imageWritten'] == true;
    final jsonWritten = result?['jsonWritten'] == true;

    if (jsonWritten != true) {
      debugPrint('[WidgetService] native json write failed');
      return false;
    }

    debugPrint(
      '[WidgetService] sync ok: petId=$petId name=$petName '
      'url=${petImageUrl.isEmpty ? '-' : petImageUrl} '
      'local=${localImagePath ?? '-'} '
      'imageWritten=$imageWritten',
    );
    return imageWritten || petImageUrl.isEmpty;
  }

  Future<bool> _waitForNativeChannel() async {
    for (var i = 0; i < 40; i++) {
      try {
        final path = await _channel.invokeMethod<String>('getAppGroupPath');
        if (path != null && path.trim().isNotEmpty) return true;
      } catch (e) {
        if (i == 0 || i == 39) {
          debugPrint('[WidgetService] wait channel ($i): $e');
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  String? _firstLocalPath(List<String> candidates) {
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
        continue;
      }
      var path = candidate;
      if (path.startsWith('file://')) {
        path = path.replaceFirst('file://', '');
      }
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  Future<String?> _prepareWidgetImagePath(
    List<String> candidates, {
    required int? petId,
  }) async {
    for (final candidate in candidates) {
      final bytes = await _readCandidateBytes(candidate);
      if (bytes == null || bytes.isEmpty) continue;

      final png = await _normalizeToPng(bytes);
      if (png == null || png.isEmpty) continue;

      try {
        final dir = await getApplicationDocumentsDirectory();
        final suffix = petId?.toString() ?? 'current';
        final target = File('${dir.path}/pet_widget_normalized_$suffix.png');
        await target.writeAsBytes(png, flush: true);
        return target.path;
      } catch (e) {
        debugPrint('[WidgetService] write normalized png failed: $e');
      }
    }
    return _firstLocalPath(candidates);
  }

  Future<Uint8List?> _readCandidateBytes(String candidate) async {
    if (candidate.isEmpty) return null;
    if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
      return _downloadBytes(candidate);
    }

    var path = candidate;
    if (path.startsWith('file://')) {
      path =
          Uri.tryParse(path)?.toFilePath() ?? path.replaceFirst('file://', '');
    }
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return await file.readAsBytes();
    } catch (e) {
      debugPrint('[WidgetService] read local image failed ($path): $e');
      return null;
    }
  }

  Future<Uint8List?> _loadRemoteImageBytes(List<String> candidates) async {
    for (final candidate in candidates) {
      if (!candidate.startsWith('http://') &&
          !candidate.startsWith('https://')) {
        continue;
      }
      final bytes = await _downloadBytes(candidate);
      if (bytes != null && bytes.isNotEmpty) {
        final png = await _normalizeToPng(bytes);
        if (png != null && png.isNotEmpty) return png;
      }
    }
    return null;
  }

  Future<Uint8List?> _normalizeToPng(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      final png = data?.buffer.asUint8List();
      if (png != null && png.isNotEmpty) return png;
    } catch (e) {
      debugPrint('[WidgetService] normalize png failed: $e');
    }
    return bytes;
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final token = AuthSessionStore.instance.token;
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = token.startsWith('Bearer ')
            ? token
            : 'Bearer $token';
      }

      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          headers: headers,
          followRedirects: true,
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } catch (e) {
      debugPrint('[WidgetService] download failed ($url): $e');
      return null;
    }
  }
}
