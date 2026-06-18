import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../common/pet_avatar_image.dart';
import 'restarting_asset_gif.dart';

/// 悬浮宠物：有 GIF 时先加载完成，再停 0.5s 后水平自动游走，始终可拖动
class DraggableFloatingPet extends StatefulWidget {
  final Offset position;
  final double size;
  final double bottomInset;
  /// 每次召唤递增，使 GIF 从第一帧重新播放
  final int animationEpoch;
  /// 接口 animated_image
  final String? animatedImage;
  /// 无 GIF 或 GIF 加载失败时展示（与首页宠物头像一致，一般为 profile.image）
  final String? fallbackImage;
  final ValueChanged<Offset>? onPositionChanged;

  const DraggableFloatingPet({
    super.key,
    required this.position,
    this.animationEpoch = 0,
    this.animatedImage,
    this.fallbackImage,
    this.size = 72,
    this.bottomInset = 0,
    this.onPositionChanged,
  });

  @override
  State<DraggableFloatingPet> createState() => _DraggableFloatingPetState();
}

class _DraggableFloatingPetState extends State<DraggableFloatingPet>
    with SingleTickerProviderStateMixin {
  static const _summonDelay = Duration(milliseconds: 500);
  static const _walkSpeed = 15.0;

  late Offset _position;
  late Ticker _ticker;

  late double _laneY;
  late double _rightX;
  late double _leftX;

  bool _isDragging = false;
  bool _gifLoading = false;
  bool _walkingToLeft = true;
  bool _summonDelayActive = false;
  DateTime? _summonDelayStartedAt;
  DateTime? _lastMoveAt;

  Rect? _moveBounds;

  String get _gifUrl => widget.animatedImage?.trim() ?? '';
  String get _fallbackUrl => widget.fallbackImage?.trim() ?? '';
  bool get _hasGif => _gifUrl.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _position = widget.position;
    _walkingToLeft = true;
    _gifLoading = _hasGif;
    _ticker = createTicker(_onTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncWalkLane();
      if (_hasGif) _startSummonDelay();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DraggableFloatingPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationEpoch != oldWidget.animationEpoch) {
      _position = widget.position;
      _walkingToLeft = true;
      _gifLoading = _hasGif;
      _syncWalkLane();
      if (_hasGif) {
        _startSummonDelay();
      } else {
        _summonDelayActive = false;
        if (_ticker.isActive) _ticker.stop();
      }
    } else if (oldWidget.animatedImage != widget.animatedImage) {
      _gifLoading = _hasGif;
      if (_hasGif) {
        _startSummonDelay();
      } else if (_ticker.isActive) {
        _ticker.stop();
      }
    }
  }

  Rect _boundsFor(Size screenSize, EdgeInsets padding) {
    return Rect.fromLTRB(
      padding.left,
      padding.top,
      screenSize.width - widget.size - padding.right,
      screenSize.height - widget.size - padding.bottom - widget.bottomInset,
    );
  }

  void _syncWalkLane() {
    final bounds = _moveBounds;
    if (bounds == null) return;
    _leftX = bounds.left;
    _rightX = bounds.right;
    _laneY = _position.dy.clamp(bounds.top, bounds.bottom);
  }

  double get _currentLaneY {
    final bounds = _moveBounds;
    if (bounds == null) return _laneY;
    return _position.dy.clamp(bounds.top, bounds.bottom);
  }

  void _clampPosition() {
    final bounds = _moveBounds;
    if (bounds == null) return;
    _position = Offset(
      _position.dx.clamp(bounds.left, bounds.right),
      _position.dy.clamp(bounds.top, bounds.bottom),
    );
    widget.onPositionChanged?.call(_position);
  }

  void _startSummonDelay() {
    _summonDelayActive = true;
    _lastMoveAt = null;
    // GIF 已缓存秒开时，从当前时刻开始计 0.5s
    _summonDelayStartedAt = _gifLoading ? null : DateTime.now();
    if (!_ticker.isActive) _ticker.start();
  }

  void _onGifLoadingChanged(bool loading) {
    if (!_hasGif || _gifLoading == loading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hasGif || _gifLoading == loading) return;
      setState(() {
        _gifLoading = loading;
        if (loading) {
          _lastMoveAt = null;
          if (_summonDelayActive) _summonDelayStartedAt = null;
        } else if (_summonDelayActive && _summonDelayStartedAt == null) {
          // GIF 显示后再开始 0.5s 停顿
          _summonDelayStartedAt = DateTime.now();
        }
      });
    });
  }

  void _onTick(Duration _) {
    if (!mounted || !_hasGif || _isDragging) return;

    if (_summonDelayActive) {
      final started = _summonDelayStartedAt;
      if (started == null) return;
      if (DateTime.now().difference(started) < _summonDelay) return;
      _summonDelayActive = false;
      _lastMoveAt = null;
    }

    if (_gifLoading) return;

    final now = DateTime.now();
    if (_lastMoveAt != null) {
      final dtSeconds = now.difference(_lastMoveAt!).inMicroseconds / 1000000.0;
      _stepWalk(dtSeconds);
    }
    _lastMoveAt = now;
  }

  void _stepWalk(double dtSeconds) {
    if (dtSeconds <= 0) return;

    final y = _currentLaneY;
    final dx = _walkingToLeft ? -_walkSpeed * dtSeconds : _walkSpeed * dtSeconds;
    var newX = _position.dx + dx;
    var newFacingLeft = _walkingToLeft;

    if (newX <= _leftX) {
      newX = _leftX;
      newFacingLeft = false;
    } else if (newX >= _rightX) {
      newX = _rightX;
      newFacingLeft = true;
    }

    final changed = newX != _position.dx || newFacingLeft != _walkingToLeft;
    if (!changed) return;

    setState(() {
      _position = Offset(newX, y);
      _walkingToLeft = newFacingLeft;
      _laneY = y;
    });
    widget.onPositionChanged?.call(_position);
  }

  void _beginDrag() {
    _isDragging = true;
    _lastMoveAt = null;
  }

  void _endDrag() {
    _isDragging = false;
    _clampPosition();
    _syncWalkLane();
    _lastMoveAt = null;
  }

  Widget _buildPetBody() {
    if (_hasGif) {
      return RestartingAssetGif(
        url: _gifUrl,
        fallbackUrl: _fallbackUrl.isNotEmpty ? _fallbackUrl : null,
        epoch: widget.animationEpoch,
        width: widget.size,
        height: widget.size,
        onLoadingChanged: _onGifLoadingChanged,
      );
    }
    if (_fallbackUrl.isNotEmpty) {
      return PetAvatarImage(
        url: _fallbackUrl,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    }
    return SizedBox(width: widget.size, height: widget.size);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = media.padding;
    _moveBounds = _boundsFor(media.size, padding);
    _syncWalkLane();

    final petBody = _hasGif
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
              _walkingToLeft ? 1.0 : -1.0,
              1.0,
              1.0,
            ),
            child: _buildPetBody(),
          )
        : _buildPetBody();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) => _beginDrag(),
        onPanUpdate: (details) {
          setState(() => _position += details.delta);
          widget.onPositionChanged?.call(_position);
        },
        onPanEnd: (_) {
          _endDrag();
          setState(() {});
        },
        onPanCancel: () {
          _endDrag();
          setState(() {});
        },
        child: petBody,
      ),
    );
  }
}
