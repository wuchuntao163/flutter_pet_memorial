import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/tr.dart';
import 'memorial_image_capture.dart';
import 'memorial_share_platform.dart';

enum MemorialShareTarget {
  wechatSession,
  wechatTimeline,
  xiaohongshu;

  String get label {
    switch (this) {
      case MemorialShareTarget.wechatSession:
        return tr('share.wechat');
      case MemorialShareTarget.wechatTimeline:
        return tr('share.wechat_timeline');
      case MemorialShareTarget.xiaohongshu:
        return tr('share.xiaohongshu');
    }
  }
}

class MemorialShareResult {
  final bool success;
  final String? message;

  const MemorialShareResult({required this.success, this.message});
}

/// 纪念日图片分享
class MemorialShareService {
  MemorialShareService._();

  static Future<MemorialShareResult> sharePreview({
    required GlobalKey boundaryKey,
    required MemorialShareTarget target,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final bytes = await MemorialImageCapture.capturePng(boundaryKey);
      final file = await _writeTempPng(bytes);
      return _shareFile(
        file: file,
        target: target,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      return MemorialShareResult(success: false, message: '$e');
    }
  }

  static Future<File> _writeTempPng(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/memorial_share_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<MemorialShareResult> _shareFile({
    required File file,
    required MemorialShareTarget target,
    Rect? sharePositionOrigin,
  }) async {
    final path = file.path;
    final xFile = XFile(path, mimeType: 'image/png');

    if (Platform.isAndroid) {
      switch (target) {
        case MemorialShareTarget.wechatSession:
          if (await MemorialSharePlatform.isAppInstalled(
            MemorialSharePlatform.wechatPackage,
          )) {
            final ok = await MemorialSharePlatform.shareImageToPackage(
              imagePath: path,
              packageName: MemorialSharePlatform.wechatPackage,
            );
            if (ok) {
              return const MemorialShareResult(success: true);
            }
          }
          return _systemShare(
            xFile,
            target: target,
            sharePositionOrigin: sharePositionOrigin,
            notInstalledHint: tr('share.wechat_not_installed'),
          );

        case MemorialShareTarget.wechatTimeline:
          if (await MemorialSharePlatform.isAppInstalled(
            MemorialSharePlatform.wechatPackage,
          )) {
            final ok = await MemorialSharePlatform.shareImageToWeChatTimeline(
              path,
            );
            if (ok) {
              return const MemorialShareResult(success: true);
            }
          }
          return _systemShare(
            xFile,
            target: target,
            sharePositionOrigin: sharePositionOrigin,
            notInstalledHint: tr('share.timeline_hint'),
          );

        case MemorialShareTarget.xiaohongshu:
          if (await MemorialSharePlatform.isAppInstalled(
            MemorialSharePlatform.xiaohongshuPackage,
          )) {
            final ok = await MemorialSharePlatform.shareImageToPackage(
              imagePath: path,
              packageName: MemorialSharePlatform.xiaohongshuPackage,
            );
            if (ok) {
              return const MemorialShareResult(success: true);
            }
          }
          return _systemShare(
            xFile,
            target: target,
            sharePositionOrigin: sharePositionOrigin,
            notInstalledHint: tr('share.xhs_not_installed'),
          );
      }
    }

    return _systemShare(
      xFile,
      target: target,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static Future<MemorialShareResult> _systemShare(
    XFile xFile, {
    required MemorialShareTarget target,
    Rect? sharePositionOrigin,
    String? notInstalledHint,
  }) async {
    try {
      await Share.shareXFiles(
        [xFile],
        text: '${tr('share.card_title')}${target.label}',
        subject: target.label,
        sharePositionOrigin: sharePositionOrigin,
      );
      return MemorialShareResult(
        success: true,
        message: notInstalledHint,
      );
    } catch (e) {
      return MemorialShareResult(
        success: false,
        message: e.toString(),
      );
    }
  }
}
