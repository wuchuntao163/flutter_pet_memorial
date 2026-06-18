import 'package:flutter/material.dart';

import '../../config/colors.dart';

/// 网络 GIF，每次 epoch 变化从第一帧重新播放
class RestartingAssetGif extends StatefulWidget {
  final String? url;
  final String? fallbackUrl;
  final int epoch;
  final double width;
  final double height;
  final ValueChanged<bool>? onLoadingChanged;

  const RestartingAssetGif({
    super.key,
    this.url,
    this.fallbackUrl,
    required this.epoch,
    required this.width,
    required this.height,
    this.onLoadingChanged,
  });

  @override
  State<RestartingAssetGif> createState() => _RestartingAssetGifState();
}

class _RestartingAssetGifState extends State<RestartingAssetGif> {
  String get _url => widget.url?.trim() ?? '';

  void _notifyLoading(bool loading) {
    widget.onLoadingChanged?.call(loading);
  }

  void _resetGifCache() {
    if (_url.isEmpty) return;
    NetworkImage(_url).evict();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  void initState() {
    super.initState();
    _resetGifCache();
  }

  @override
  void dispose() {
    _resetGifCache();
    super.dispose();
  }

  @override
  void didUpdateWidget(RestartingAssetGif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.epoch != widget.epoch || oldWidget.url != widget.url) {
      _resetGifCache();
      if (_url.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notifyLoading(true);
        });
      }
    }
  }

  String get _fallback => widget.fallbackUrl?.trim() ?? '';

  Widget _fallbackImage() {
    if (_fallback.isEmpty) {
      return SizedBox(width: widget.width, height: widget.height);
    }
    return Image.network(
      _fallback,
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          SizedBox(width: widget.width, height: widget.height),
    );
  }

  Widget _loading() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_url.isEmpty) return _fallbackImage();
    return Image.network(
      _url,
      key: ValueKey('${_url}_${widget.epoch}'),
      width: widget.width,
      height: widget.height,
      fit: BoxFit.contain,
      gaplessPlayback: false,
      loadingBuilder: (context, child, progress) {
        final loading = progress != null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notifyLoading(loading);
        });
        if (loading) return _loading();
        return child;
      },
      errorBuilder: (_, _, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _notifyLoading(false);
        });
        return _fallbackImage();
      },
    );
  }
}
