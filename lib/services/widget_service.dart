import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/app_cache_store.dart';
import '../data/auth_session_store.dart';
import '../data/memorial_store.dart';
import '../data/pet_avatar_store.dart';
import 'pet_image_service.dart';

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
      final rawImageUrl = _resolvePetImageRaw() ?? '';
      final petImageUrl = PetImageService.resolveUrl(rawImageUrl);
      final petImageBytes = await _loadPetImageBytes(petImageUrl, rawImageUrl);

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

      await _channel.invokeMethod<void>('updateWidget', payload);

      if (kDebugMode) {
        debugPrint(
          '[WidgetService] updateWidget ok: name=$petName '
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

  /// 与 App 内展示逻辑一致：档案图 → AI 生成图 → 动图
  static String? _resolvePetImageRaw() {
    final profile = AppCacheStore.instance.petProfile;
    final fromProfile = profile?['image']?.toString().trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;

    final custom = PetAvatarStore.customAvatarUrl?.trim();
    if (custom != null && custom.isNotEmpty) return custom;

    final animated = profile?['animated_image']?.toString().trim();
    if (animated != null && animated.isNotEmpty) return animated;

    return null;
  }

  Future<Uint8List?> _loadPetImageBytes(
    String resolvedUrl,
    String rawUrl,
  ) async {
    for (final candidate in <String>{rawUrl, resolvedUrl}) {
      if (candidate.isEmpty) continue;
      final local = await _readLocalImageBytes(candidate);
      if (local != null && local.isNotEmpty) return local;
    }

    if (resolvedUrl.isEmpty ||
        (!resolvedUrl.startsWith('http://') &&
            !resolvedUrl.startsWith('https://'))) {
      return null;
    }

    try {
      final token = AuthSessionStore.instance.token;
      final headers = <String, dynamic>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] =
            token.startsWith('Bearer ') ? token : 'Bearer $token';
      }

      final response = await Dio().get<List<int>>(
        resolvedUrl,
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
        debugPrint('[WidgetService] download image failed: $e');
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
