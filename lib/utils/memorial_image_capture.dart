import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 从 RepaintBoundary 导出 PNG 字节
class MemorialImageCapture {
  MemorialImageCapture._();

  static Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = 3,
  }) async {
    final boundary = boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('预览区域未就绪');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('图片生成失败');
    }

    return byteData.buffer.asUint8List();
  }
}
