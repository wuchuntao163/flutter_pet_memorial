import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_cache_store.dart';
import '../l10n/tr.dart';

/// 「我的」页：推荐分享、应用商店评分
/// 链接字段来自 getConfig 返回的 config：share_url、day_customer_service_link、android_store_url、ios_store_url
class AppPromotionUtil {
  AppPromotionUtil._();

  static const _androidPackage = 'com.jnr.flutter_pet_memorial';

  static String get _appName {
    final info = AppCacheStore.instance.info;
    if (info is Map) {
      final name = info['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return tr('promotion.app_name');
  }

  /// getConfig → data.config 中的字段
  static String? _configString(String key) {
    final config = AppCacheStore.instance.config;
    if (config is! Map) return null;
    final value = config[key]?.toString();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String get _shareText {
    final link = _configString('share_url');
    final intro =
        tr('promotion.intro').replaceAll(tr('promotion.app_name'), _appName);
    return link != null ? '$intro\n$link' : intro;
  }

  static Future<void> shareRecommend({Rect? sharePositionOrigin}) async {
    await Share.share(
      _shareText,
      subject: _appName,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<bool> openCustomerService() async {
    final url = _configString('day_customer_service_link');
    if (url == null) return false;
    return _openUrl(url);
  }

  static Future<bool> openAppStoreRating() async {
    if (Platform.isIOS) {
      final url = _configString('ios_store_url');
      if (url == null) return false;
      return _openUrl(url);
    }

    if (Platform.isAndroid) {
      final urls = <String>[
        ?_configString('android_store_url'),
        'market://details?id=$_androidPackage',
        'https://play.google.com/store/apps/details?id=$_androidPackage',
      ];
      for (final url in urls) {
        if (await _openUrl(url)) return true;
      }
    }
    return false;
  }

  static Future<bool> _openUrl(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
