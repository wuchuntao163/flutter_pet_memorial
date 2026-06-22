import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_info.dart';
import '../data/app_cache_store.dart';
import '../l10n/tr.dart';
import '../router/app_router.dart';
import '../widgets/dialogs/app_update_dialog.dart';
import 'app_promotion_util.dart';
import 'app_version_util.dart';
import 'center_tip_util.dart';

class AppUpdateCheckResult {
  final String localVersion;
  final String? remoteVersion;
  final String tips;
  final bool hasUpdate;

  const AppUpdateCheckResult({
    required this.localVersion,
    required this.remoteVersion,
    required this.tips,
    required this.hasUpdate,
  });
}

class AppUpdateUtil {
  AppUpdateUtil._();

  static bool _homeCheckedThisSession = false;
  static String? _cachedLocalVersion;

  static String? _configString(String key) {
    final config = AppCacheStore.instance.config;
    if (config is! Map) return null;
    final value = config[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static Future<String> currentVersion() async {
    if (_cachedLocalVersion != null) return _cachedLocalVersion!;

    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      if (version.isNotEmpty) {
        _cachedLocalVersion = version;
        return version;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppUpdateUtil] PackageInfo failed, use fallback: $e');
      }
    }

    _cachedLocalVersion = AppInfo.version;
    return AppInfo.version;
  }

  static Future<AppUpdateCheckResult> check({bool forceRefresh = false}) async {
    if (forceRefresh) {
      await AppCacheStore.instance.fetchConfig(force: true);
    } else {
      await AppCacheStore.instance.fetchConfig();
    }

    final localVersion = await currentVersion();
    final remoteVersion = _configString('app_version');
    final tips = _configString('update_tips') ?? tr('update.default_tips');
    final hasUpdate = remoteVersion != null &&
        AppVersionUtil.isRemoteNewer(remoteVersion, localVersion);

    return AppUpdateCheckResult(
      localVersion: localVersion,
      remoteVersion: remoteVersion,
      tips: tips,
      hasUpdate: hasUpdate,
    );
  }

  static Future<void> checkOnHomeLaunch([BuildContext? context]) async {
    if (_homeCheckedThisSession) return;

    final result = await check();
    if (!result.hasUpdate) {
      _homeCheckedThisSession = true;
      return;
    }

    for (var i = 0; i < 30; i++) {
      final ctx = context ?? rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await _showUpdateDialog(ctx, result.tips);
        _homeCheckedThisSession = true;
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  static Future<void> checkOnVersionTap(BuildContext context) async {
    final result = await check(forceRefresh: true);
    if (!context.mounted) return;

    if (result.hasUpdate) {
      await _showUpdateDialog(context, result.tips);
      return;
    }
    showCenterTip(context, tr('update.already_latest'));
  }

  static Future<void> _showUpdateDialog(
    BuildContext context,
    String tips,
  ) async {
    final confirmed = await AppUpdateDialog.show(context, message: tips);
    if (confirmed != true || !context.mounted) return;

    final ok = await AppPromotionUtil.openAppStoreRating();
    if (!context.mounted) return;
    if (!ok) {
      showCenterTip(context, tr('profile.cannot_open_store'));
    }
  }
}
