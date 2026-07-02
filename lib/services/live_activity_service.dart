import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_cache_store.dart';
import '../l10n/tr.dart';

/// iOS 灵动岛 / Live Activity：与桌面小组件独立，复用 App Group 宠物 PNG。
class LiveActivityService {
  LiveActivityService._();

  static final LiveActivityService instance = LiveActivityService._();

  static const _prefsKey = 'live_activity_enabled';
  static const _channel = MethodChannel(
    'com.example.flutterPetMemorial/live_activity',
  );

  bool? _supportedCache;

  bool get isPlatformSupported => Platform.isIOS;

  Future<bool> isSupported() async {
    if (!isPlatformSupported) return false;
    _supportedCache ??= await _channel.invokeMethod<bool>('isSupported') ?? false;
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
