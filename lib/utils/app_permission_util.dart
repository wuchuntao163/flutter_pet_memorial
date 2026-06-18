import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:photo_manager/photo_manager.dart';

import '../l10n/tr.dart';

enum AppPermissionType { gallery, camera, albumSave }

class AppPermissionDeniedException implements Exception {
  const AppPermissionDeniedException(this.type, {this.canOpenSettings = true});

  final AppPermissionType type;
  final bool canOpenSettings;

  @override
  String toString() => 'AppPermissionDeniedException($type)';
}

/// 相册读取、相机、相册写入等权限的统一申请与引导
class AppPermissionUtil {
  AppPermissionUtil._();

  static bool _isGalleryGranted(PermissionState state) {
    return state.isAuth || state.hasAccess;
  }

  static String messageKey(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.gallery:
        return 'permissions.gallery_denied';
      case AppPermissionType.camera:
        return 'permissions.camera_denied';
      case AppPermissionType.albumSave:
        return 'permissions.album_save_denied';
    }
  }

  /// 申请相册读取权限（选择照片）
  static Future<void> ensureGalleryAccess() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    if (_isGalleryGranted(state)) return;
    throw const AppPermissionDeniedException(AppPermissionType.gallery);
  }

  /// 申请相册写入权限（保存图片）
  static Future<void> ensureAlbumSaveAccess() async {
    final hasAccess = await Gal.requestAccess(toAlbum: true);
    if (hasAccess) return;
    throw const AppPermissionDeniedException(AppPermissionType.albumSave);
  }

  static Future<void> openAppSettings() => PhotoManager.openSetting();

  /// 权限被拒时弹窗引导用户前往系统设置
  static Future<void> showDeniedDialog(
    BuildContext context,
    AppPermissionDeniedException error,
  ) async {
    if (!context.mounted) return;

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr(messageKey(error.type))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('common.cancel')),
          ),
          if (error.canOpenSettings)
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('permissions.open_settings')),
            ),
        ],
      ),
    );

    if (openSettings == true) {
      await openAppSettings();
    }
  }
}
