import 'dart:io';

import 'package:flutter/material.dart';

import '../services/pet_image_service.dart';
import 'app_permission_util.dart';
import 'center_tip_util.dart';
import 'pet_image_picker.dart';
import 'saving_overlay.dart';

/// 灵动岛配置页：相册选图 → `/api/base/upload` → 返回可展示的网络 URL。
Future<String?> pickAndUploadIslandImage(BuildContext context) async {
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    final path = await PetImagePicker.pickFromGallery(context);
    if (path == null || path.isEmpty || !context.mounted) return null;
    final url = await withSavingOverlay(context, () async {
      final uploaded = await PetImageService.upload(path);
      if (context.mounted) {
        await precacheImage(NetworkImage(uploaded), context);
      }
      return uploaded;
    });
    return url;
  } on AppPermissionDeniedException catch (error) {
    if (context.mounted) {
      await AppPermissionUtil.showDeniedDialog(context, error);
    }
    return null;
  } catch (error) {
    debugPrint('[IslandImage] upload failed: $error');
    if (context.mounted) {
      await showCenterTip(context, '图片上传失败');
    }
    return null;
  }
}

/// 展示灵动岛预览图：优先网络 URL，兼容本地路径 / asset。
Widget islandImage(
  String? source, {
  required double width,
  required double height,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
}) {
  final fallback =
      placeholder ??
      Image.asset(
        'assets/images/addvalentine.png',
        width: width,
        height: height,
        fit: fit,
      );
  final value = source?.trim() ?? '';
  if (value.isEmpty) return fallback;

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return Image.network(
      value,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
  if (value.startsWith('assets/')) {
    return Image.asset(value, width: width, height: height, fit: fit);
  }

  final path = value.startsWith('file://')
      ? Uri.parse(value).toFilePath()
      : value;
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => fallback,
  );
}

/// 各岛通知版预览统一尺寸（与正计时 / 纪念日一致）
const double kIslandPreviewCardWidth = 245;
const double kIslandPreviewCardHeight = 82;
