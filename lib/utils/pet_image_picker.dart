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
        pickerTheme: AssetPicker.themeData(AppColors.accent, light: true),
      ),
    );
    if (assets == null || assets.isEmpty) return null;

    final file = await assets.first.originFile;
    return file?.path;
  }

  /// 选择透明组件使用的壁纸原图，不压缩或降低画质。
  static Future<String?> pickOriginalWallpaper(BuildContext context) async {
    await AppPermissionUtil.ensureGalleryAccess();
    if (!context.mounted) return null;

    // 优先取相册原图路径（含 HEIC），避免临时压缩副本
    try {
      final assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          maxAssets: 1,
          requestType: RequestType.image,
          textDelegate: const AssetPickerTextDelegate(),
          pickerTheme: AssetPicker.themeData(AppColors.accent, light: true),
        ),
      );
      if (assets == null || assets.isEmpty) return null;
      final file = await assets.first.originFile;
      if (file != null && file.path.isNotEmpty) return file.path;
    } catch (error) {
      debugPrint('[PetImagePicker] origin wallpaper pick fallback: $error');
    }

    if (!context.mounted) return null;
    if (!Platform.isIOS) {
      return pickFromGallery(context);
    }

    try {
      final file = await _cameraPicker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: true,
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

  /// 打开相册选择多张图片
  static Future<List<String>> pickMultipleFromGallery(
    BuildContext context, {
    int maxAssets = 3,
  }) async {
    await AppPermissionUtil.ensureGalleryAccess();
    if (!context.mounted) return const [];

    if (Platform.isIOS) {
      try {
        final files = await _cameraPicker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 88,
        );
        return files.take(maxAssets).map((f) => f.path).toList();
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
        maxAssets: maxAssets,
        requestType: RequestType.image,
        textDelegate: const AssetPickerTextDelegate(),
        pickerTheme: AssetPicker.themeData(AppColors.accent, light: true),
      ),
    );
    if (assets == null || assets.isEmpty) return const [];

    final paths = <String>[];
    for (final asset in assets) {
      final file = await asset.originFile;
      final path = file?.path;
      if (path != null && path.isNotEmpty) paths.add(path);
    }
    return paths;
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
