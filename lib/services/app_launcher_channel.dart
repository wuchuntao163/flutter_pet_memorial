import 'package:flutter/services.dart';

/// 从桌面悬浮窗等独立引擎拉起主应用
class AppLauncherChannel {
  AppLauncherChannel._();

  static const _channel = MethodChannel('com.jnr.flutter_pet_memorial/launcher');

  static Future<bool> launchMainApp() async {
    try {
      final ok = await _channel.invokeMethod<bool>('launchMainApp');
      return ok == true;
    } catch (_) {
      return false;
    }
  }
}
