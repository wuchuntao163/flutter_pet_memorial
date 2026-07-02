import 'dart:io' show Platform;

import 'desktop_pet_overlay_service.dart';
import 'live_activity_service.dart';
import 'widget_service.dart';

/// 宠物资料变更后按平台同步：Android 悬浮窗 / iOS 桌面组件。
class PlatformPetSync {
  PlatformPetSync._();

  static Future<void> afterProfileUpdate() async {
    if (Platform.isAndroid) {
      await DesktopPetOverlayService.syncIfEnabled();
      return;
    }
    if (Platform.isIOS) {
      await WidgetService.instance.updateWidget();
      await LiveActivityService.instance.syncIfEnabled();
    }
  }

  /// 纪念日等数据变更后刷新 iOS 小组件。
  static Future<void> afterDataUpdate() async {
    if (!Platform.isIOS) return;
    await WidgetService.instance.updateWidget();
    await LiveActivityService.instance.syncIfEnabled();
  }
}
