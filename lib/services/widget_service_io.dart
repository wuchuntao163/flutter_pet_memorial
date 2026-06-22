import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/app_cache_store.dart';
import '../data/memorial_store.dart';
import '../data/pet_avatar_store.dart';
import 'widget_service_stub.dart' as stub;

/// iOS 桌面组件数据同步；其他平台直接 no-op。
class WidgetServiceImpl {
  static const _channel =
      MethodChannel('com.gjl.PetMemorialDay/widget');

  Future<void> updateWidget() async {
    if (!Platform.isIOS) {
      return stub.WidgetServiceImpl().updateWidget();
    }

    try {
      final cache = AppCacheStore.instance;
      final profile = cache.petProfile;
      final memorials = MemorialStore.instance.items;

      final petName = profile?['nickname']?.toString().trim() ??
          profile?['name']?.toString().trim() ??
          '';
      final petType = profile?['type']?.toString() ??
          profile?['pet_type']?.toString() ??
          '';
      final petAge = '${cache.accompanyDays}';
      final petImageUrl = profile?['image']?.toString().trim() ??
          PetAvatarStore.customAvatarUrl?.trim() ??
          '';

      final memorialPayload = memorials
          .take(10)
          .map(
            (day) => {
              'id': day.id,
              'title': day.title,
              'days': day.displayDayCount,
              'status': day.statusLabel,
            },
          )
          .toList();

      await _channel.invokeMethod<void>('updateWidget', {
        'petName': petName,
        'petType': petType,
        'petAge': petAge,
        'petImageUrl': petImageUrl,
        'memorials': jsonEncode(memorialPayload),
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[WidgetService] updateWidget failed: $e\n$st');
      }
    }
  }
}
