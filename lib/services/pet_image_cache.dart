import 'package:flutter/widgets.dart';

import 'pet_image_service.dart';

/// 已加载过的宠物图片 URL，避免 Tab / 语言切换时反复空白或转圈
class PetImageCache {
  PetImageCache._();

  static final PetImageCache instance = PetImageCache._();

  final Set<String> _ready = {};

  String resolve(String? url) {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return '';
    return PetImageService.resolveUrl(raw);
  }

  bool isReady(String? url) {
    final resolved = resolve(url);
    return resolved.isNotEmpty && _ready.contains(resolved);
  }

  void markReady(String resolved) {
    if (resolved.isNotEmpty) _ready.add(resolved);
  }

  Future<void> precache(BuildContext context, String? url) async {
    final resolved = resolve(url);
    if (resolved.isEmpty || _ready.contains(resolved)) return;
    if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
      return;
    }
    try {
      await precacheImage(NetworkImage(resolved), context);
      _ready.add(resolved);
    } catch (_) {}
  }
}
