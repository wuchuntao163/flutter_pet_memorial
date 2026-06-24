import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../config/colors.dart';
import '../../services/desktop_pet_overlay_service.dart';
import 'restarting_asset_gif.dart';

/// 桌面悬浮窗内的宠物 UI（独立 Flutter 引擎入口）
/// 自动游走已暂时关闭；拖动由原生实现
class DesktopPetOverlay extends StatefulWidget {
  const DesktopPetOverlay({super.key});

  @override
  State<DesktopPetOverlay> createState() => _DesktopPetOverlayState();
}

class _DesktopPetOverlayState extends State<DesktopPetOverlay> {
  static const _size = DesktopPetOverlayService.petSize;

  String? _gifUrl;
  String? _imageUrl;
  int _epoch = 0;
  StreamSubscription<dynamic>? _subscription;

  // double _screenW = 400;

  bool _gifLoading = false;
  bool _walkingToLeft = true;

  bool get _hasGif => _gifUrl?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _gifLoading = _hasGif;
    _subscription = FlutterOverlayWindow.overlayListener.listen(_onOverlayData);
  }

  @override
  void dispose() {
    // FlutterOverlayWindow.setAutoWalk(
    //   enabled: false,
    //   screenW: _screenW,
    //   petW: _size,
    // );
    _subscription?.cancel();
    super.dispose();
  }

  void _onOverlayData(dynamic event) {
    if (event is! String || event.isEmpty) return;
    try {
      final map = jsonDecode(event) as Map<String, dynamic>;
      final type = map['event']?.toString();

      // if (type == 'walk_dir') {
      //   final left = map['left'];
      //   if (left is bool && mounted) {
      //     setState(() => _walkingToLeft = left);
      //   }
      //   return;
      // }
      if (type == 'walk_dir') return;

      if (type == 'touch_down' || type == 'touch_up') return;

      final nextGif = map['gif']?.toString();
      final nextImage = map['image']?.toString();
      if (nextGif != _gifUrl || nextImage != _imageUrl) {
        _gifUrl = nextGif;
        _imageUrl = nextImage;
        _epoch++;
        _gifLoading = _hasGif;
      }
      // if (map['screenW'] is num) _screenW = (map['screenW'] as num).toDouble();
      // _updateAutoWalk();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // Future<void> _updateAutoWalk() async {
  //   await FlutterOverlayWindow.setAutoWalk(
  //     enabled: _hasGif && !_gifLoading,
  //     screenW: _screenW,
  //     petW: _size,
  //   );
  // }

  void _onGifLoadingChanged(bool loading) {
    if (!_hasGif || _gifLoading == loading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasGif || _gifLoading == loading) return;
      setState(() => _gifLoading = loading);
      // _updateAutoWalk();
    });
  }

  Widget _buildPetImage() {
    final hasGif = _hasGif;
    final hasImage = _imageUrl?.isNotEmpty == true;
    if (!hasGif && !hasImage) {
      return Icon(Icons.pets, size: _size * 0.6, color: AppColors.accent);
    }

    Widget body = RestartingAssetGif(
      url: _gifUrl,
      fallbackUrl: _imageUrl,
      epoch: _epoch,
      width: _size,
      height: _size,
      onLoadingChanged: _onGifLoadingChanged,
    );

    if (hasGif) {
      body = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          _walkingToLeft ? 1.0 : -1.0,
          1.0,
          1.0,
        ),
        child: body,
      );
    }

    return body;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: _size,
        height: _size,
        child: _buildPetImage(),
      ),
    );
  }
}
