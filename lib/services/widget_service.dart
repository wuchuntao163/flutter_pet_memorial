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

/// iOS 主屏幕小组件：Flutter 直接写入 App Group（JSON + PNG），避免通道传大图失败
class WidgetService {
  WidgetService._();

  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel('com.example.flutterPetMemorial/widget');

  String? _appGroupPath;
  int? _lastSyncedPetId;
  String? _lastSyncedImageKey;

  Future<void> updateWidget({int retries = 3}) async {
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
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    if (lastError != null) {
      debugPrint('[WidgetService] all retries failed: $lastError');
    }
  }

  Future<bool> _updateWidgetOnce() async {
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

    if (petChanged || imageChanged) {
      await _clearAppGroupImage();
    }

    final petImageBytes = await _loadPetImageBytes(imageCandidates);

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

    final widgetJson = <String, dynamic>{
      'petId': '${petId ?? ''}',
      'petName': petName,
      'petType': petType,
      'petAge': petAge,
      'petImageUrl': petImageUrl,
      'memorials': jsonEncode(memorialPayload),
    };

    final payloadWritten = await _writePayloadToAppGroup(
      widgetJson: widgetJson,
      imageBytes: petImageBytes,
    );

    if (!payloadWritten) {
      debugPrint('[WidgetService] write app group failed');
      return false;
    }

    final token = AuthSessionStore.instance.token;
    await _channel.invokeMethod<void>('reloadWidget', {
      'authToken': token ?? '',
      'petImageUrl': petImageUrl,
      'imageWritten': petImageBytes != null && petImageBytes.isNotEmpty,
    });

    _lastSyncedPetId = petId;
    _lastSyncedImageKey = imageKey;

    debugPrint(
      '[WidgetService] sync ok: petId=$petId name=$petName '
      'url=${petImageUrl.isEmpty ? '-' : petImageUrl} '
      'bytes=${petImageBytes?.length ?? 0} '
      'petChanged=$petChanged',
    );
    return true;
  }

  Future<String?> _getAppGroupPath() async {
    if (_appGroupPath != null && _appGroupPath!.isNotEmpty) {
      return _appGroupPath;
    }
    try {
      final path = await _channel.invokeMethod<String>('getAppGroupPath');
      if (path != null && path.trim().isNotEmpty) {
        _appGroupPath = path.trim();
        return _appGroupPath;
      }
    } catch (e) {
      debugPrint('[WidgetService] getAppGroupPath failed: $e');
    }
    return null;
  }

  Future<bool> _writePayloadToAppGroup({
    required Map<String, dynamic> widgetJson,
    Uint8List? imageBytes,
  }) async {
    final appGroupPath = await _getAppGroupPath();
    if (appGroupPath == null) return false;

    try {
      final jsonFile = File(
        '$appGroupPath/${PetDisplayImage.widgetDataFileName}',
      );
      await jsonFile.writeAsString(jsonEncode(widgetJson), flush: true);

      final imageFile = File(
        '$appGroupPath/${PetDisplayImage.widgetImageFileName}',
      );
      if (imageBytes != null && imageBytes.isNotEmpty) {
        await imageFile.writeAsBytes(imageBytes, flush: true);
      } else if (await imageFile.exists()) {
        await imageFile.delete();
      }

      return await jsonFile.exists();
    } catch (e) {
      debugPrint('[WidgetService] write payload failed: $e');
      return false;
    }
  }

  Future<void> _clearAppGroupImage() async {
    final appGroupPath = await _getAppGroupPath();
    if (appGroupPath == null) return;
    try {
      final file = File(
        '$appGroupPath/${PetDisplayImage.widgetImageFileName}',
      );
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[WidgetService] clear image failed: $e');
    }
  }

  Future<Uint8List?> _loadPetImageBytes(List<String> candidates) async {
    for (final candidate in candidates) {
      final local = await _readLocalImageBytes(candidate);
      if (local != null && local.isNotEmpty) {
        final png = await _normalizeToPng(local);
        if (png != null && png.isNotEmpty) return png;
      }
    }

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

  Future<Uint8List?> _readLocalImageBytes(String path) async {
    if (path.isEmpty) return null;

    if (path.startsWith('file://')) {
      final file = File(path.replaceFirst('file://', ''));
      if (await file.exists()) return file.readAsBytes();
      return null;
    }

    if (!path.startsWith('http://') && !path.startsWith('https://')) {
      final file = File(path);
      if (await file.exists()) return file.readAsBytes();
    }

    return null;
  }
}
