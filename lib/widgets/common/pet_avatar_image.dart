import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../services/pet_image_cache.dart';
import '../../services/pet_image_service.dart';

/// 宠物形象网络图；同 URL 已加载过则切换 Tab / 语言时不再闪空
class PetAvatarImage extends StatefulWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? loading;
  final Widget? error;

  const PetAvatarImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.loading,
    this.error,
  });

  @override
  State<PetAvatarImage> createState() => _PetAvatarImageState();
}

class _PetAvatarImageState extends State<PetAvatarImage> {
  static const _loadTimeout = Duration(seconds: 25);
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _precache();
    _startTimeout();
  }

  @override
  void didUpdateWidget(PetAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _timedOut = false;
      _precache();
      _startTimeout();
    }
  }

  void _precache() {
    final resolved = _resolvedUrl;
    if (resolved.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PetImageCache.instance.precache(context, resolved);
    });
  }

  void _startTimeout() {
    final resolved = _resolvedUrl;
    if (resolved.isEmpty || PetImageCache.instance.isReady(resolved)) return;
    Future.delayed(_loadTimeout, () {
      if (mounted && !_timedOut && !PetImageCache.instance.isReady(resolved)) {
        setState(() => _timedOut = true);
      }
    });
  }

  String get _resolvedUrl {
    final raw = widget.url?.trim() ?? '';
    if (raw.isEmpty) return '';
    return PetImageService.resolveUrl(raw);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedUrl;
    if (resolved.isEmpty) {
      return widget.error ?? _error();
    }
    if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
      return widget.error ?? _error();
    }

    final cached = PetImageCache.instance.isReady(resolved);
    if (_timedOut && !cached) {
      return widget.error ?? _error();
    }

    return Image.network(
      resolved,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) {
          PetImageCache.instance.markReady(resolved);
        }
        if (wasSynchronouslyLoaded ||
            frame != null ||
            PetImageCache.instance.isReady(resolved)) {
          return child;
        }
        return widget.loading ?? _loading();
      },
      errorBuilder: (_, _, _) => widget.error ?? _error(),
    );
  }

  Widget _loading() {
    final base = widget.width ?? widget.height ?? 40;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(
        child: SizedBox(
          width: base * 0.45,
          height: base * 0.45,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  Widget _error() {
    return SizedBox(width: widget.width, height: widget.height);
  }
}
