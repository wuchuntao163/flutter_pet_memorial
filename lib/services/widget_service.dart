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

/// iOS 主屏幕小组件服务
class WidgetService {
  WidgetService._();

  static final WidgetService instance = WidgetService._();

  static const _channel = MethodChannel('com.example.flutterPetMemorial/widget');

  /// 更新小组件数据
  Future<void> updateWidget() async {
    if (!Platform.isIOS) return;

    try {
      final cache = AppCacheStore.instance;
      final profile = cache.petProfile;
      final memorials = MemorialStore.instance.items;

      final petName =
          profile?['nickname']?.toString().trim() ??
          profile?['name']?.toString().trim() ??
          '';
      final petType =
          profile?['type']?.toString() ??
          profile?['pet_type']?.toString() ??
          '';
      final petAge = '${cache.accompanyDays}';

      final imageCandidates = PetDisplayImage.downloadCandidates();
      final petImageUrl =
          imageCandidates.isNotEmpty ? imageCandidates.first : '';
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

      final token = AuthSessionStore.instance.token;
      final payload = <String, dynamic>{
        'petName': petName,
        'petType': petType,
        'petAge': petAge,
        'petImageUrl': petImageUrl,
        'memorials': jsonEncode(memorialPayload),
      };
      if (petImageBytes != null && petImageBytes.isNotEmpty) {
        payload['petImageBytes'] = petImageBytes;
      }
      if (token != null && token.isNotEmpty) {
        payload['authToken'] = token;
      }

      await _channel.invokeMethod<void>('updateWidget', payload);

      if (kDebugMode) {
        debugPrint(
          '[WidgetService] updateWidget ok: name=$petName '
          'displayRaw=${PetDisplayImage.resolveRaw() ?? '-'} '
          'url=${petImageUrl.isEmpty ? '-' : petImageUrl} '
          'bytes=${petImageBytes?.length ?? 0}',
        );
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[WidgetService] updateWidget platform error: '
          '${e.code} ${e.message}',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[WidgetService] updateWidget failed: $e\n$st');
      }
    }
  }

  Future<Uint8List?> _loadPetImageBytes(List<String> candidates) async {
    for (final candidate in candidates) {
      final local = await _readLocalImageBytes(candidate);
      if (local != null && local.isNotEmpty) {
        return _normalizeToPng(local);
      }
    }

    for (final candidate in candidates) {
      if (!candidate.startsWith('http://') &&
          !candidate.startsWith('https://')) {
        continue;
      }
      final bytes = await _downloadBytes(candidate);
      if (bytes != null && bytes.isNotEmpty) {
        return _normalizeToPng(bytes);
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
      if (kDebugMode) {
        debugPrint('[WidgetService] normalize png failed: $e');
      }
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
        ),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WidgetService] download image failed ($url): $e');
      }
      return null;
    }
  }

  Future<Uint8List?> _readLocalImageBytes(String path) async {
    if (path.isEmpty) return null;

    if (path.startsWith('file://')) {
      final file = File(path.replaceFirst('file://', ''));
      if (await file.exists()) {
        return file.readAsBytes();
      }
      return null;
    }

    if (!path.startsWith('http://') && !path.startsWith('https://')) {
      final file = File(path);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }

    return null;
  }
}
