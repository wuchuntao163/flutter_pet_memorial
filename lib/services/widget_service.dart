import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/app_cache_store.dart';
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
      final rawImageUrl =
          profile?['image']?.toString().trim() ??
          profile?['animated_image']?.toString().trim() ??
          PetAvatarStore.customAvatarUrl?.trim() ??
          '';
      final petImageUrl = PetImageService.resolveUrl(rawImageUrl);
      final petImageBytes = await _loadPetImageBytes(petImageUrl);

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

  Future<Uint8List?> _loadPetImageBytes(String url) async {
    if (url.isEmpty) return null;

    if (url.startsWith('file://')) {
      final file = File(url.replaceFirst('file://', ''));
      if (await file.exists()) {
        return file.readAsBytes();
      }
      return null;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final file = File(url);
      if (await file.exists()) {
        return file.readAsBytes();
      }
      return null;
    }

    try {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
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
}
