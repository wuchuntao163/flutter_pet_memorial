import 'package:flutter/material.dart';

import 'package:gal/gal.dart';

import 'app_permission_util.dart';
import 'memorial_image_capture.dart';



/// 将 RepaintBoundary 导出并保存到系统相册

class MemorialImageSaver {

  MemorialImageSaver._();



  static Future<void> saveRepaintBoundary(GlobalKey boundaryKey) async {

    await AppPermissionUtil.ensureAlbumSaveAccess();



    final bytes = await MemorialImageCapture.capturePng(boundaryKey);

    await Gal.putImageBytes(bytes);

  }

}


