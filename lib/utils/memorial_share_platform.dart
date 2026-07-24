import 'dart:io';

import 'package:flutter/services.dart';

/// 分享到第三方 App（Android 定向唤起；iOS 由上层回退系统分享）
class MemorialSharePlatform {
  MemorialSharePlatform._();

  static const _channel =
      MethodChannel('com.jnr.flutter_pet_memorial/share');

  static const wechatPackage = 'com.tencent.mm';
  static const xiaohongshuPackage = 'com.xingin.xhs';

  static Future<bool> isAppInstalled(String packageName) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'isAppInstalled',
        {'package': packageName},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 将图片分享到指定 Android 应用
  static Future<bool> shareImageToPackage({
    required String imagePath,
    required String packageName,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'shareImageToPackage',
        {
          'path': imagePath,
          'package': packageName,
        },
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 微信朋友圈（Android 需微信 SDK；此处尝试唤起微信）
  static Future<bool> shareImageToWeChatTimeline(String imagePath) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'shareImageToWeChatTimeline',
        {'path': imagePath},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
