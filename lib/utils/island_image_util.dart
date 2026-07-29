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

/// 各岛通知版预览统一高度
const double kIslandPreviewCardHeight = 117;

/// 兜底宽度（无 BuildContext 时）；优先用 [islandPreviewCardWidth]
const double kIslandPreviewCardWidth = 330;

/// 展开预览卡宽度：与下方配置区内容左右边距 20 对齐（比固定 330 更宽）
double islandPreviewCardWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width - 40).clamp(330.0, 420.0);
}

/// 灵动岛胶囊预览（窄条）
const double kIslandCompactWidth = 136;
const double kIslandCompactHeight = 36;

/// 图文岛未选相册时的默认左侧图（与预览 placeholder 一致）
const String kPhotoIslandDefaultImage = 'assets/images/addvalentine.png';

/// 自定义岛未选面板时的本地兜底图
const String kCustomIslandDefaultPanel = 'assets/images/image_87.png';

/// 详情 `default_icon` 是否为图片地址（网络 / asset），否则按 emoji 文本处理
bool islandDefaultIconIsImage(String value) {
  final v = value.trim();
  if (v.isEmpty) return false;
  final lower = v.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('assets/')) {
    return true;
  }
  return lower.contains('.png') ||
      lower.contains('.jpg') ||
      lower.contains('.jpeg') ||
      lower.contains('.webp') ||
      lower.contains('.gif');
}

/// 图文岛通知版左侧图形状：圆角矩形（非正圆）
Widget islandCardSideImage(
  String? source, {
  required double size,
  bool circular = false,
  BoxFit fit = BoxFit.cover,
  Widget? placeholder,
}) {
  final image = islandImage(
    source,
    width: size,
    height: size,
    fit: fit,
    placeholder: placeholder,
  );
  final clipped = circular
      ? ClipOval(child: image)
      : ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: image,
        );
  return SizedBox(width: size, height: size, child: clipped);
}
