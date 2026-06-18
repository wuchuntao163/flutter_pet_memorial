import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../config/colors.dart';
import 'app_permission_util.dart';

/// 相册网格选择（非系统文件管理器）+ 相机拍照
class PetImagePicker {
  PetImagePicker._();

  static final _cameraPicker = ImagePicker();

  /// 打开相册选择图片
  static Future<String?> pickFromGallery(BuildContext context) async {
    await AppPermissionUtil.ensureGalleryAccess();
    if (!context.mounted) return null;

    if (Platform.isIOS) {
      try {
        final file = await _cameraPicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 88,
        );
        return file?.path;
      } on PlatformException catch (e) {
        if (e.code == 'photo_access_denied' ||
            e.code == 'photo_access_restricted') {
          throw const AppPermissionDeniedException(AppPermissionType.gallery);
        }
        rethrow;
      }
    }

    final assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
        textDelegate: const AssetPickerTextDelegate(),
        pickerTheme: AssetPicker.themeData(
          AppColors.accent,
          light: true,
        ),
      ),
    );
    if (assets == null || assets.isEmpty) return null;

    final file = await assets.first.originFile;
    return file?.path;
  }

  /// 相机拍照
  static Future<String?> pickFromCamera() async {
    try {
      final file = await _cameraPicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      return file?.path;
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' ||
          e.code == 'camera_access_restricted') {
        throw const AppPermissionDeniedException(AppPermissionType.camera);
      }
      rethrow;
    }
  }
}
