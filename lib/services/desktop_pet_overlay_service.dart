import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_cache_store.dart';
import '../l10n/tr.dart';
import '../data/pet_avatar_store.dart';

/// Android 桌面悬浮宠物：显示在其他应用/桌面之上，点击打开主应用
class DesktopPetOverlayService {
  DesktopPetOverlayService._();

  static const _prefsKey = 'desktop_pet_enabled';
  static const petSize = 260.0;
  static const _petSizeInt = 260;
  /// 与原生 OverlayConstants.POSITION_BOTTOM_RIGHT 对应；
  /// 具体偏移在 OverlayService.positionOverlayBottomRight 中计算
  static const _startBottomRight = OverlayPosition(-7, -7);

  static bool get isSupported => Platform.isAndroid;

  static Future<bool> isEnabled() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  static Future<bool> ensurePermission() async {
    if (!isSupported) return false;
    if (await FlutterOverlayWindow.isPermissionGranted()) return true;
    final granted = await FlutterOverlayWindow.requestPermission();
    return granted == true;
  }

  static Future<bool> setEnabled(bool enabled) async {
    if (!isSupported) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);

    if (enabled) {
      final ok = await ensurePermission();
      if (!ok) {
        await prefs.setBool(_prefsKey, false);
        return false;
      }
      await showFromCurrentProfile();
      return true;
    }

    await hide();
    return true;
  }

  static Future<void> hide() async {
    if (!isSupported) return;
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  static Future<void> showFromCurrentProfile() async {
    if (!isSupported) return;
    final profile = AppCacheStore.instance.petProfile;
    final gif = profile?['animated_image']?.toString();
    final image = profile?['image']?.toString() ??
        PetAvatarStore.customAvatarUrl;
    await showPet(gifUrl: gif, imageUrl: image);
  }

  static Future<void> syncIfEnabled() async {
    if (!isSupported || !await isEnabled()) return;
    final profile = AppCacheStore.instance.petProfile;
    final gif = profile?['animated_image']?.toString();
    final image = profile?['image']?.toString() ??
        PetAvatarStore.customAvatarUrl;
    final payload = _buildPayload(gifUrl: gif, imageUrl: image);

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.resizeOverlay(_petSizeInt, _petSizeInt, true);
      await FlutterOverlayWindow.shareData(payload);
      return;
    }

    await showPet(gifUrl: gif, imageUrl: image);
  }

  static String _buildPayload({String? gifUrl, String? imageUrl}) {
    final size = _screenSize();
    return jsonEncode({
      'gif': gifUrl?.trim() ?? '',
      'image': imageUrl?.trim() ?? '',
      'screenW': size.width,
      'screenH': size.height,
    });
  }

  static ({double width, double height}) _screenSize() {
    final views = ui.PlatformDispatcher.instance.views;
    var screenW = 400.0;
    var screenH = 800.0;
    if (views.isNotEmpty) {
      final view = views.first;
      final ratio = view.devicePixelRatio;
      screenW = view.physicalSize.width / ratio;
      screenH = view.physicalSize.height / ratio;
    }
    return (width: screenW, height: screenH);
  }

  static Future<void> showPet({
    String? gifUrl,
    String? imageUrl,
  }) async {
    if (!isSupported) return;

    final payload = _buildPayload(gifUrl: gifUrl, imageUrl: imageUrl);

    if (await FlutterOverlayWindow.isActive()) {
      await hide();
    }

    await FlutterOverlayWindow.showOverlay(
      height: _petSizeInt,
      width: _petSizeInt,
      alignment: OverlayAlignment.topLeft,
      enableDrag: true,
      positionGravity: PositionGravity.none,
      flag: OverlayFlag.focusPointer,
      overlayTitle: tr('desktop_pet.overlay_title'),
      overlayContent: tr('desktop_pet.overlay_content'),
      startPosition: _startBottomRight,
    );
    // 等悬浮窗 View 就绪后再推送数据，避免首次开启时前台不显示
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await FlutterOverlayWindow.shareData(payload);
  }
}
