import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/tr.dart';
import 'center_tip_util.dart';

/// Banner 平台过滤与点击跳转（对齐 uniapp getBanner / clickBanner）
class BannerUtil {
  BannerUtil._();

  static List<Map<String, dynamic>> filterByPlatform(
    List<Map<String, dynamic>> list,
  ) {
    return list.where(shouldShowOnCurrentPlatform).toList();
  }

  static bool shouldShowOnCurrentPlatform(Map<String, dynamic> item) {
    final raw = item['show_platform'];
    if (raw == null) return true;

    final platform = _parseShowPlatform(raw);
    if (platform.isEmpty) return true;

    if (Platform.isIOS) {
      return _platformEnabled(platform['ios']);
    }
    if (Platform.isAndroid) {
      return _platformEnabled(platform['and']);
    }
    return false;
  }

  static Map<String, dynamic> _parseShowPlatform(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {};
  }

  static bool _platformEnabled(dynamic value) {
    if (value == null) return false;
    if (value is num) return value > 0;
    if (value is String) {
      final n = int.tryParse(value);
      return n != null && n > 0;
    }
    return false;
  }

  static Future<void> onBannerTap(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final type = _asInt(item['type']);
    switch (type) {
      case 1:
        await _openMiniProgram(context, item);
      case 2:
        await _openWebPage(item['url']?.toString());
      case 3:
        _navigateInternal(context, item['url']?.toString());
      case 4:
        await _runThirdApp(context, item);
      default:
        await _openWebPage(item['url']?.toString());
    }
  }

  static Future<void> _openMiniProgram(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _showToast(context, tr('banner.mini_program_unsupported'));
      return;
    }

    final originalId = item['original_id']?.toString() ?? '';
    final appletId = item['applet_id']?.toString() ?? '';
    final path = item['pages']?.toString() ?? '';
    if (originalId.isEmpty && appletId.isEmpty) return;

    final confirmed = await _confirm(
      context,
      title: tr('banner.open_wechat_title'),
      content: tr('banner.open_wechat_content'),
    );
    if (confirmed != true || !context.mounted) return;

    if (Platform.isAndroid) {
      final launched = await _launchAndroidMiniProgram(
        originalId: originalId,
        appletId: appletId,
        path: path,
      );
      if (!launched && context.mounted) {
        _showToast(context, tr('banner.mini_program_unsupported'));
      }
      return;
    }

    final launched = await _launchIosMiniProgram(
      originalId: originalId,
      appletId: appletId,
      path: path,
    );
    if (!launched && context.mounted) {
      _showToast(context, tr('banner.mini_program_unsupported'));
    }
  }

  static Future<bool> _launchAndroidMiniProgram({
    required String originalId,
    required String appletId,
    required String path,
  }) async {
    if (appletId.isNotEmpty) {
      final uri = Uri.parse(
        'weixin://dl/business/?appid=$appletId&path=${Uri.encodeComponent(path)}',
      );
      if (await _launchUri(uri)) return true;
    }

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: 'com.tencent.mm',
        flags: [268435456],
      );
      await intent.launch();
      return true;
    } catch (_) {}

    return _launchUri(Uri.parse('weixin://'));
  }

  static Future<bool> _launchIosMiniProgram({
    required String originalId,
    required String appletId,
    required String path,
  }) async {
    if (appletId.isNotEmpty) {
      final uri = Uri.parse(
        'weixin://dl/business/?appid=$appletId&path=${Uri.encodeComponent(path)}',
      );
      if (await _launchUri(uri)) return true;
    }
    if (originalId.isNotEmpty && path.isNotEmpty) {
      final uri = Uri.parse(
        'weixin://dl/business/?username=$originalId&path=${Uri.encodeComponent(path)}',
      );
      if (await _launchUri(uri)) return true;
    }
    return _launchUri(Uri.parse('weixin://'));
  }

  static Future<void> _openWebPage(String? url) async {
    if (url == null || url.isEmpty) return;
    await _launchUri(Uri.tryParse(url));
  }

  static void _navigateInternal(BuildContext context, String? url) {
    if (url == null || url.isEmpty) return;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      _openWebPage(url);
      return;
    }
    final path = url.startsWith('/') ? url : '/$url';
    context.push(path);
  }

  static Future<void> _runThirdApp(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    if (Platform.isAndroid) {
      final package = item['package_name']?.toString() ?? '';
      if (package.isEmpty) return;
      final launched = await _launchAndroidApp(package);
      if (!launched) {
        await _openWebPage(item['download_url']?.toString());
      }
      return;
    }
    if (Platform.isIOS) {
      await _openWebPage(
        item['download_url']?.toString() ?? item['url']?.toString(),
      );
    }
  }

  static Future<bool> _launchAndroidApp(String packageName) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: packageName,
        flags: [268435456],
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _launchUri(Uri? uri) async {
    if (uri == null) return false;
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  static Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('common.confirm')),
          ),
        ],
      ),
    );
  }

  static void _showToast(BuildContext context, String message) {
    showCenterTip(context, message);
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }
}
