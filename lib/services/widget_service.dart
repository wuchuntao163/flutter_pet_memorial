import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/app_cache_store.dart';
import '../data/auth_session_store.dart';
import '../data/memorial_store.dart';
import '../utils/pet_display_image.dart';

/// iOS 主屏幕小组件：由原生写入 App Group（JSON + PNG），避免 Dart 直写失败
class WidgetService {
  WidgetService._();

  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel('com.example.flutterPetMemorial/widget');

  int? _lastSyncedPetId;
  String? _lastSyncedImageKey;

  Future<void> updateWidget({int retries = 5}) async {
    if (!Platform.isIOS) return;

    AppCacheStore.instance.repairLocalPetImage();

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
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
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
        profile?['type']?.toString() ??
        profile?['pet_type']?.toString() ??
        '';
    final petAge = '${cache.accompanyDays}';

    final imageCandidates = await PetDisplayImage.downloadCandidates();
    final petImageUrl =
        imageCandidates.isNotEmpty ? imageCandidates.first : '';
    final imageKey = '${petId ?? 0}|$petImageUrl';
    final petChanged = petId != _lastSyncedPetId;
    final imageChanged = imageKey != _lastSyncedImageKey;
    final clearImage = petChanged || imageChanged;

    final localImagePath = _firstLocalPath(imageCandidates);
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
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'syncWidget',
      {
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
        'clearImage': clearImage,
      },
    );

    final imageWritten = result?['imageWritten'] == true;
    final jsonWritten = result?['jsonWritten'] == true;

    if (jsonWritten != true) {
      debugPrint('[WidgetService] native json write failed');
      return false;
    }

    _lastSyncedPetId = petId;
    _lastSyncedImageKey = imageKey;

    debugPrint(
      '[WidgetService] sync ok: petId=$petId name=$petName '
      'url=${petImageUrl.isEmpty ? '-' : petImageUrl} '
      'local=${localImagePath ?? '-'} '
      'imageWritten=$imageWritten clear=$clearImage',
    );
    return true;
  }

  Future<bool> _waitForNativeChannel() async {
    for (var i = 0; i < 30; i++) {
      try {
        final path = await _channel.invokeMethod<String>('getAppGroupPath');
        if (path != null && path.trim().isNotEmpty) return true;
      } catch (e) {
        if (i == 0 || i == 29) {
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
        headers['Authorization'] =
            token.startsWith('Bearer ') ? token : 'Bearer $token';
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
