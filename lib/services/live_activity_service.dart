import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_cache_store.dart';
import '../data/auth_session_store.dart';
import '../data/memorial_store.dart';
import '../l10n/tr.dart';
import '../utils/island_image_util.dart';
import '../utils/pet_display_image.dart';
import 'pet_image_service.dart';

/// iOS 灵动岛 / Live Activity：按模板 1–6 同步，同时仅一个岛。
class LiveActivityService {
  LiveActivityService._();

  static final LiveActivityService instance = LiveActivityService._();

  static const prefsEnabledKey = 'live_activity_enabled';
  static const activeTemplateKey = 'active_island_template';

  static const petIslandEnabledKey = 'pet_island_enabled';
  static const photoIslandEnabledKey = 'photo_island_enabled';
  static const memorialIslandEnabledKey = 'memorial_island_enabled';
  static const countUpEnabledKey = 'count_up_island_enabled';
  static const countDownEnabledKey = 'count_down_island_enabled';
  static const customIslandEnabledKey = 'custom_island_enabled';

  static const _channel = MethodChannel(
    'com.example.flutterPetMemorial/live_activity',
  );

  bool? _supportedCache;
  String? _lastSyncedImageKey;
  static const _syncKeyVersion = 4;

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
    return prefs.getBool(prefsEnabledKey) ?? false;
  }

  Future<int?> activeTemplate() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(activeTemplateKey);
    if (value == null || value < 1 || value > 6) return null;
    return value;
  }

  /// 档案/引导总开关：开启则同步当前激活模板（无则回退模板 1）。
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
      await prefs.setBool(prefsEnabledKey, true);
      return true;
    }

    await prefs.setBool(prefsEnabledKey, false);
    await _clearAllIslandEnabledFlags(prefs);
    await prefs.remove(activeTemplateKey);
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

  /// 配置页上岛：互斥开启 [template]，写入 payload 并启动/更新 Activity。
  Future<bool> startOrUpdateIsland({
    required int template,
    required Map<String, dynamic> payload,
    Map<String, String?> assetPaths = const {},
  }) async {
    if (!await isSupported()) return false;
    if (!await areActivitiesEnabled()) return false;
    if (template < 1 || template > 6) return false;

    final prefs = await SharedPreferences.getInstance();

    // 模板 1：可用显式宠物/四叶草 URL；否则用配置缓存
    if (template == 1) {
      final petUrl = assetPaths['petUrl'] ?? '';
      final cloverUrl = assetPaths['cloverUrl'] ?? '';
      if (petUrl.isNotEmpty || cloverUrl.isNotEmpty) {
        await _syncRemoteImages(
          petImageUrl: petUrl,
          fourCloverUrl: cloverUrl,
          force: true,
        );
      } else {
        await _syncLiveActivityImage(force: true);
      }
      final bannerBg = assetPaths['bannerBg'];
      if (bannerBg != null && bannerBg.trim().isNotEmpty) {
        await syncAsset(
          role: 'bannerBg',
          imagePath: _resolveAssetRef(bannerBg),
        );
      }
    } else {
      final clearable = <String>{
        if (template == 2) 'photo',
        if (template == 3 || template == 4 || template == 5) 'icon',
        if (template == 6) ...['panel', 'leftIcon', 'rightIcon'],
      };
      final provided = <String>{};
      for (final entry in assetPaths.entries) {
        final path = entry.value;
        if (path == null || path.trim().isEmpty) continue;
        if (entry.key == 'petUrl' || entry.key == 'cloverUrl') continue;
        provided.add(entry.key);
        await syncAsset(role: entry.key, imagePath: _resolveAssetRef(path));
      }
      // 未再上传的图片角色：清掉 App Group，避免切回 emoji 仍显示旧图
      for (final role in clearable) {
        if (!provided.contains(role)) {
          await clearAsset(role);
        }
      }
    }

    final body = <String, dynamic>{
      'petId': '${AppCacheStore.instance.petId ?? ''}',
      'template': template,
      ...payload,
    };

    try {
      final ok =
          await _channel.invokeMethod<bool>('updateActivity', body) ?? false;
      debugPrint('[LiveActivityService] startOrUpdate template=$template ok=$ok');
      if (!ok) return false;
      await _clearOtherIslandEnabledFlags(prefs, keepTemplate: template);
      await prefs.setInt(activeTemplateKey, template);
      await prefs.setBool(prefsEnabledKey, true);
      await prefs.setBool(_enabledKeyForTemplate(template), true);
      return true;
    } catch (e, st) {
      debugPrint('[LiveActivityService] startOrUpdate failed: $e\n$st');
      return false;
    }
  }

  /// 配置页关岛（仅当当前激活模板匹配时结束 Activity）。
  Future<void> disableIsland(int template) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKeyForTemplate(template), false);
    final active = prefs.getInt(activeTemplateKey);
    if (active == template) {
      await prefs.remove(activeTemplateKey);
      await prefs.setBool(prefsEnabledKey, false);
      await endActivity();
    }
  }

  Future<bool> syncAsset({
    required String role,
    String? imagePath,
    String? imageBase64,
  }) async {
    if (!await isSupported()) return false;
    try {
      var path = imagePath?.trim();
      var base64 = imageBase64;
      // 仅网络图 / Flutter asset 需转 base64；本地文件路径交给原生直接读
      if ((base64 == null || base64.isEmpty) &&
          path != null &&
          path.isNotEmpty &&
          (path.startsWith('http://') ||
              path.startsWith('https://') ||
              path.startsWith('assets/'))) {
        final resolved = await _resolveImageBytes(path);
        if (resolved != null) {
          base64 = base64Encode(resolved);
          path = null;
        }
      }
      final ok =
          await _channel.invokeMethod<bool>('syncAsset', {
            'role': role,
            if (path != null && path.isNotEmpty) 'imagePath': path,
            if (base64 != null && base64.isNotEmpty) 'imageBase64': base64,
          }) ??
          false;
      return ok;
    } catch (e, st) {
      debugPrint('[LiveActivityService] syncAsset $role failed: $e\n$st');
      return false;
    }
  }

  /// 清除某角色 App Group 图片（相册切回 emoji 时）
  Future<bool> clearAsset(String role) async {
    if (!await isSupported()) return false;
    try {
      return await _channel.invokeMethod<bool>('clearAsset', {'role': role}) ??
          false;
    } catch (e, st) {
      debugPrint('[LiveActivityService] clearAsset $role failed: $e\n$st');
      return false;
    }
  }

  Future<Uint8List?> _resolveImageBytes(String raw) async {
    final value = raw.trim();
    if (value.isEmpty) return null;
    try {
      final remote = _resolveAssetRef(value);
      if (remote.startsWith('http://') || remote.startsWith('https://')) {
        final response = await Dio().get<List<int>>(
          remote,
          options: Options(responseType: ResponseType.bytes),
        );
        final data = response.data;
        if (data != null && data.isNotEmpty) {
          return Uint8List.fromList(data);
        }
        return null;
      }
      if (value.startsWith('assets/')) {
        final data = await rootBundle.load(value);
        return data.buffer.asUint8List();
      }
      final cleaned = value.startsWith('file://')
          ? Uri.parse(value).toFilePath()
          : value;
      final file = File(cleaned);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    } catch (e, st) {
      debugPrint('[LiveActivityService] resolve image failed: $e\n$st');
    }
    return null;
  }

  /// 网络相对路径补全；本地文件路径原样返回。
  String _resolveAssetRef(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('assets/')) {
      return PetImageService.resolveUrl(value);
    }
    if (value.startsWith('/uploads/') || value.startsWith('uploads/')) {
      return PetImageService.resolveUrl(value);
    }
    return value;
  }

  /// 用户已开启且系统允许时，按 active 模板重算内容。
  Future<bool> syncIfEnabled({bool force = false}) async {
    if (!await isSupported()) return false;
    if (!force && !await isEnabled()) return false;
    if (!await areActivitiesEnabled()) return false;

    final prefs = await SharedPreferences.getInstance();
    final template = prefs.getInt(activeTemplateKey) ?? 1;

    if (template == 1) {
      await _syncLiveActivityImage(force: force);
      final banner = prefs.getString('pet_island_banner_bg');
      if (banner != null && banner.isNotEmpty) {
        await syncAsset(role: 'bannerBg', imagePath: _resolveAssetRef(banner));
      }
    }
    if (template == 2) {
      final photo = prefs.getString('photo_island_image');
      final banner = prefs.getString('photo_island_banner_bg');
      final photoPath =
          (photo != null && photo.isNotEmpty) ? photo : kPhotoIslandDefaultImage;
      await syncAsset(role: 'photo', imagePath: _resolveAssetRef(photoPath));
      if (banner != null && banner.isNotEmpty) {
        await syncAsset(role: 'bannerBg', imagePath: _resolveAssetRef(banner));
      }
    }
    if (template == 6) {
      final panel = prefs.getString('custom_island_panel_image');
      final fallback = prefs.getString('custom_island_panel_fallback');
      final panelPath = (panel != null && panel.isNotEmpty)
          ? panel
          : ((fallback != null && fallback.isNotEmpty)
                ? fallback
                : kCustomIslandDefaultPanel);
      await syncAsset(role: 'panel', imagePath: _resolveAssetRef(panelPath));
      final left = prefs.getString('custom_island_left_icon_image') ??
          prefs.getString('custom_island_icon_image');
      final right = prefs.getString('custom_island_right_icon_image');
      if (left != null && left.isNotEmpty) {
        await syncAsset(role: 'leftIcon', imagePath: _resolveAssetRef(left));
      }
      if (right != null && right.isNotEmpty) {
        await syncAsset(role: 'rightIcon', imagePath: _resolveAssetRef(right));
      }
    }
    if (template == 5) {
      await MemorialStore.instance.ensureMemorialsLoaded();
    }

    final payload = await buildPayloadForActiveTemplate(prefs);
    if (payload == null) return false;

    try {
      final ok =
          await _channel.invokeMethod<bool>('updateActivity', payload) ?? false;
      debugPrint('[LiveActivityService] sync ok=$ok template=$template');
      return ok;
    } catch (e, st) {
      debugPrint('[LiveActivityService] sync failed: $e\n$st');
      return false;
    }
  }

  /// 供配置页/同步入口组装当前激活模板 payload。
  Future<Map<String, dynamic>?> buildPayloadForActiveTemplate(
    SharedPreferences prefs,
  ) async {
    final template = prefs.getInt(activeTemplateKey) ?? 1;
    switch (template) {
      case 2:
        return _payloadPhoto(prefs);
      case 3:
        return _payloadTimer(prefs, countUp: true);
      case 4:
        return _payloadTimer(prefs, countUp: false);
      case 5:
        return _payloadMemorial(prefs);
      case 6:
        return _payloadCustom(prefs);
      default:
        return _payloadPet(prefs);
    }
  }

  Map<String, dynamic> _payloadPet(SharedPreferences prefs) {
    final cache = AppCacheStore.instance;
    final profile = cache.petProfile;
    final petName =
        profile?['nickname']?.toString().trim() ??
        profile?['name']?.toString().trim() ??
        '宠物';
    final subtitle =
        prefs.getString('pet_island_content')?.trim().isNotEmpty == true
        ? prefs.getString('pet_island_content')!.trim()
        : tr('live_activity.tagline');
    return {
      'petId': '${cache.petId ?? ''}',
      'template': 1,
      'petName': petName,
      'subtitle': subtitle,
      'memorialTitle': '',
      'backgroundColorARGB': 0xFFC5D6E2,
    };
  }

  Map<String, dynamic> _payloadPhoto(SharedPreferences prefs) {
    final cache = AppCacheStore.instance;
    final subtitle =
        prefs.getString('photo_island_content')?.trim() ?? '笨猫真可爱 >.<';
    final color = prefs.getInt('photo_island_color') ?? 0xFFFFFFFF;
    final fontSize = prefs.getDouble('photo_island_font_size') ?? 16;
    final bgColor = prefs.getInt('photo_island_bg_color') ?? 0xFFFFC7B9;
    return {
      'petId': '${cache.petId ?? ''}',
      'template': 2,
      'petName': subtitle,
      'subtitle': subtitle,
      'memorialTitle': '',
      'textColorARGB': color,
      'textFontSize': fontSize,
      'backgroundColorARGB': bgColor,
    };
  }

  Map<String, dynamic> _payloadTimer(
    SharedPreferences prefs, {
    required bool countUp,
  }) {
    final prefix = countUp ? 'count_up_island' : 'count_down_island';
    final title =
        prefs.getString('${prefix}_title')?.trim() ??
        (countUp ? '学英语1小时已经' : '距离下班还有');
    final hour = prefs.getInt('${prefix}_hour') ?? 18;
    final minute = prefs.getInt('${prefix}_minute') ?? 30;
    final icon = prefs.getString('${prefix}_icon') ?? '🔔';
    final epoch = _timerTargetEpoch(
      hour: hour,
      minute: minute,
      countUp: countUp,
    );
    return {
      'petId': '${AppCacheStore.instance.petId ?? ''}',
      'template': countUp ? 3 : 4,
      'petName': title,
      'subtitle': title,
      'memorialTitle': title,
      'timerTargetEpoch': epoch,
      'compactLeadingEmoji': icon,
      'backgroundColorARGB': countUp ? 0xFF000000 : 0xFFE4F0FF,
    };
  }

  Map<String, dynamic> _payloadMemorial(SharedPreferences prefs) {
    final selectedId = prefs.getString('memorial_island_selected_id');
    final items = MemorialStore.instance.items;
    dynamic selected;
    for (final item in items) {
      if (item.id == selectedId) {
        selected = item;
        break;
      }
    }
    selected ??= items.isEmpty ? null : items.first;
    final title = selected == null
        ? '纪念日'
        : (selected.title?.toString().trim().isNotEmpty == true
              ? selected.title.toString().trim()
              : '纪念日');
    final rawDays = selected == null
        ? '—'
        : selected.formattedDayCount.toString();
    final daysText = rawDays == '—'
        ? '—'
        : (rawDays.contains('天') ? rawDays : '$rawDays天');
    final icon = prefs.getString('memorial_island_icon') ?? '❤️';
    return {
      'petId': '${AppCacheStore.instance.petId ?? ''}',
      'template': 5,
      'petName': title,
      'subtitle': title,
      'memorialTitle': title,
      'daysText': daysText,
      'compactLeadingEmoji': icon,
    };
  }

  Map<String, dynamic> _payloadCustom(SharedPreferences prefs) {
    const prefix = 'custom_island';
    final content = prefs.getString('${prefix}_content')?.trim() ?? '';
    final color = prefs.getInt('${prefix}_text_color') ?? 0xFFFFFFFF;
    final x = prefs.getDouble('${prefix}_text_x') ?? 0.58;
    final y = prefs.getDouble('${prefix}_text_y') ?? 0.72;
    final left =
        prefs.getString('${prefix}_left_icon') ??
        prefs.getString('${prefix}_icon') ??
        '🌈';
    final right = prefs.getString('${prefix}_right_icon') ?? '🔔';
    return {
      'petId': '${AppCacheStore.instance.petId ?? ''}',
      'template': 6,
      'petName': content.isEmpty ? '自定义' : content,
      'subtitle': content,
      'memorialTitle': '',
      'textColorARGB': color,
      'textFontSize': 18,
      'textNormX': x,
      'textNormY': y,
      'compactLeadingEmoji': left,
      'compactTrailingEmoji': right,
    };
  }

  double _timerTargetEpoch({
    required int hour,
    required int minute,
    required bool countUp,
  }) {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (countUp) {
      if (target.isAfter(now)) {
        target = target.subtract(const Duration(days: 1));
      }
    } else {
      if (!target.isAfter(now)) {
        target = target.add(const Duration(days: 1));
      }
    }
    return target.millisecondsSinceEpoch / 1000.0;
  }

  Future<void> _syncLiveActivityImage({bool force = false}) async {
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
    await _syncRemoteImages(
      petImageUrl: petUrl ?? '',
      fourCloverUrl: fourCloverUrl ?? '',
      force: force,
    );
  }

  Future<void> _syncRemoteImages({
    required String petImageUrl,
    required String fourCloverUrl,
    bool force = false,
  }) async {
    if (petImageUrl.isEmpty && fourCloverUrl.isEmpty) {
      debugPrint('[LiveActivityService] no live activity images');
      return;
    }
    final type = AppCacheStore.instance.petTypeCode;
    final syncKey =
        'v$_syncKeyVersion|${type ?? 'other'}|$petImageUrl|$fourCloverUrl';
    if (!force && syncKey == _lastSyncedImageKey) {
      return;
    }

    try {
      final ok =
          await _channel.invokeMethod<bool>('syncImage', {
            'petImageUrl': petImageUrl,
            'fourCloverUrl': fourCloverUrl,
            'authToken': AuthSessionStore.instance.token ?? '',
          }) ??
          false;
      if (ok) {
        _lastSyncedImageKey = syncKey;
      }
      debugPrint(
        '[LiveActivityService] syncImage ok=$ok pet=$petImageUrl clover=$fourCloverUrl',
      );
    } catch (e, st) {
      debugPrint('[LiveActivityService] syncImage failed: $e\n$st');
    }
  }

  String _enabledKeyForTemplate(int template) {
    switch (template) {
      case 2:
        return photoIslandEnabledKey;
      case 3:
        return countUpEnabledKey;
      case 4:
        return countDownEnabledKey;
      case 5:
        return memorialIslandEnabledKey;
      case 6:
        return customIslandEnabledKey;
      default:
        return petIslandEnabledKey;
    }
  }

  Future<void> _clearOtherIslandEnabledFlags(
    SharedPreferences prefs, {
    required int keepTemplate,
  }) async {
    final keys = <int, String>{
      1: petIslandEnabledKey,
      2: photoIslandEnabledKey,
      3: countUpEnabledKey,
      4: countDownEnabledKey,
      5: memorialIslandEnabledKey,
      6: customIslandEnabledKey,
    };
    for (final entry in keys.entries) {
      if (entry.key == keepTemplate) continue;
      await prefs.setBool(entry.value, false);
    }
  }

  Future<void> _clearAllIslandEnabledFlags(SharedPreferences prefs) async {
    await prefs.setBool(petIslandEnabledKey, false);
    await prefs.setBool(photoIslandEnabledKey, false);
    await prefs.setBool(countUpEnabledKey, false);
    await prefs.setBool(countDownEnabledKey, false);
    await prefs.setBool(memorialIslandEnabledKey, false);
    await prefs.setBool(customIslandEnabledKey, false);
  }
}
