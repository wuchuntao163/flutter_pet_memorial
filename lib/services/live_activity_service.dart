import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_cache_store.dart';
import '../data/auth_session_store.dart';
import '../l10n/tr.dart';
import '../utils/pet_display_image.dart';

/// iOS 灵动岛 / Live Activity：独立图片与桌面小组件。
/// type=1/2 用配置 lingdongdog/lingdongcat，其他 type 用档案实时图。
class LiveActivityService {
  LiveActivityService._();

  static final LiveActivityService instance = LiveActivityService._();

  static const _prefsKey = 'live_activity_enabled';
  static const _channel = MethodChannel(
    'com.example.flutterPetMemorial/live_activity',
  );

  bool? _supportedCache;
  String? _lastSyncedImageKey;
  static const _syncKeyVersion = 3;

  bool get isPlatformSupported => Platform.isIOS;

  Future<bool> isSupported() async {
    if (!isPlatformSupported) return false;
    _supportedCache ??=
        await _channel.invokeMethod<bool>('isSupported') ?? false;
    return _supportedCache!;
  }

  Future<bool> areActivitiesEnabled() async {
    if (!await isSupported()) return false;
    return await _channel.invokeMethod<bool>('areActivitiesEnabled') ?? false;
  }

  Future<bool> isActive() async {
    if (!await isSupported()) return false;
    return await _channel.invokeMethod<bool>('isActive') ?? false;
  }

  Future<bool> isEnabled() async {
    if (!await isSupported()) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<bool> setEnabled(bool enabled) async {
    if (!await isSupported()) return false;

    final prefs = await SharedPreferences.getInstance();

    if (enabled) {
      final systemEnabled = await areActivitiesEnabled();
      if (!systemEnabled) {
        return false;
      }
      final ok = await syncIfEnabled(force: true);
      if (!ok) return false;
      await prefs.setBool(_prefsKey, true);
      return true;
    }

    await prefs.setBool(_prefsKey, false);
    await endActivity();
    return true;
  }

  Future<void> endActivity() async {
    if (!await isSupported()) return;
    try {
      await _channel.invokeMethod<void>('endActivity');
    } catch (e, st) {
      debugPrint('[LiveActivityService] end failed: $e\n$st');
    }
  }

  /// 用户已开启且系统允许时，同步灵动岛内容（不影响桌面小组件）。
  Future<bool> syncIfEnabled({bool force = false}) async {
    if (!await isSupported()) return false;
    if (!force && !await isEnabled()) return false;
    if (!await areActivitiesEnabled()) return false;

    await _syncLiveActivityImage();

    final payload = _buildPayload();
    if (payload == null) return false;

    try {
      final ok =
          await _channel.invokeMethod<bool>('updateActivity', payload) ?? false;
      debugPrint('[LiveActivityService] sync ok=$ok');
      return ok;
    } catch (e, st) {
      debugPrint('[LiveActivityService] sync failed: $e\n$st');
      return false;
    }
  }

  Future<void> _syncLiveActivityImage() async {
    final cache = AppCacheStore.instance;
    final type = cache.petTypeCode;
    final String? petUrl;
    if (type == 1 || type == 2) {
      petUrl = cache.liveActivityImageUrl;
    } else {
      final raw = await PetDisplayImage.resolveUrl();
      petUrl = raw.isEmpty ? null : raw;
    }
    final fourCloverUrl = cache.fourCloverImageUrl;
    if ((petUrl == null || petUrl.isEmpty) &&
        (fourCloverUrl == null || fourCloverUrl.isEmpty)) {
      debugPrint('[LiveActivityService] no live activity images');
      return;
    }
    final syncKey =
        'v$_syncKeyVersion|${type ?? 'other'}|${petUrl ?? ''}|${fourCloverUrl ?? ''}';
    if (syncKey == _lastSyncedImageKey) {
      return;
    }

    try {
      final ok =
          await _channel.invokeMethod<bool>('syncImage', {
            'petImageUrl': petUrl ?? '',
            'fourCloverUrl': fourCloverUrl ?? '',
            'authToken': AuthSessionStore.instance.token ?? '',
          }) ??
          false;
      if (ok) {
        _lastSyncedImageKey = syncKey;
      }
      debugPrint(
        '[LiveActivityService] syncImage ok=$ok pet=$petUrl clover=$fourCloverUrl',
      );
    } catch (e, st) {
      debugPrint('[LiveActivityService] syncImage failed: $e\n$st');
    }
  }

  Map<String, String>? _buildPayload() {
    final cache = AppCacheStore.instance;
    final profile = cache.petProfile;
    final petName =
        profile?['nickname']?.toString().trim() ??
        profile?['name']?.toString().trim() ??
        '';
    if (petName.isEmpty) return null;

    return {
      'petId': '${cache.petId ?? ''}',
      'petName': petName,
      'subtitle': tr('live_activity.tagline'),
      'memorialTitle': '',
    };
  }
}
