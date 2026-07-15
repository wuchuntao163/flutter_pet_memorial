import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../l10n/tr.dart';
import '../../services/pet_gif_service.dart';
import '../../services/pet_image_service.dart';
import 'pet_avatar_image.dart';

/// 宠物 GIF 生成进度：头像 +「生成中...」+ 按步骤填充的进度条
class PetGifProgressHint extends StatelessWidget {
  final PetGifTaskResult progress;
  final String? petImageUrl;

  const PetGifProgressHint({
    super.key,
    required this.progress,
    this.petImageUrl,
  });

  static const _petSize = 52.0;
  static const _labelStyle = TextStyle(
    fontSize: 12,
    height: 1.2,
    color: AppColors.textTertiary,
  );

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvedPetUrl;
    final showPet = resolved != null && resolved.isNotEmpty;
    final stepStatuses = progress.orderedStepStatuses;
    final currentIndex = progress.isReady ? -1 : progress.currentStepIndex;

    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showPet) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PetAvatarImage(
                url: resolved,
                width: _petSize,
                height: _petSize,
                loading: const SizedBox(
                  width: _petSize,
                  height: _petSize,
                ),
                error: const SizedBox(
                  width: _petSize,
                  height: _petSize,
                ),
              ),
            ),
          ],
          // 相对宠物高度垂直居中；宽度与「生成中...」文字对齐
          SizedBox(
            height: _petSize,
            child: IntrinsicWidth(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('summon.generating_short'),
                    style: _labelStyle,
                  ),
                  const SizedBox(height: 5),
                  _StepProgressBar(
                    stepStatuses: stepStatuses,
                    currentIndex: currentIndex,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? get _resolvedPetUrl {
    final raw = petImageUrl?.trim() ?? '';
    if (raw.isEmpty) return null;
    return PetImageService.resolveUrl(raw);
  }
}

/// 按接口每步 status 显示：`3` 完成、`0`/`1` 当前闪烁、其余浅色
class _StepProgressBar extends StatelessWidget {
  final List<int> stepStatuses;
  final int currentIndex;

  const _StepProgressBar({
    required this.stepStatuses,
    required this.currentIndex,
  });

  static const _barHeight = 8.0;
  static const _gap = 2.0;
  static const _doneColor = Color(0xFFF4A698);
  static const _todoColor = Color(0xFFE8D9CC);
  static const _currentColor = Color(0xFFF4A698);

  @override
  Widget build(BuildContext context) {
    final statuses = stepStatuses.isEmpty
        ? List<int>.filled(PetGifTaskResult.orderedStepKeys.length, 0)
        : stepStatuses;
    final total = statuses.length;

    return SizedBox(
      height: _barHeight,
      child: Row(
        children: List.generate(total, (index) {
          final value = statuses[index];
          final isDone = PetGifTaskResult.isStepCompleted(value);
          final isCurrent =
              index == currentIndex && PetGifTaskResult.isStepActive(value);

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : _gap / 2,
                right: index == total - 1 ? 0 : _gap / 2,
              ),
              child: isCurrent
                  ? const _CurrentStepSegment(color: _currentColor)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: isDone ? _doneColor : _todoColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const SizedBox.expand(),
                    ),
            ),
          );
        }),
      ),
    );
  }
}

class _CurrentStepSegment extends StatefulWidget {
  final Color color;

  const _CurrentStepSegment({required this.color});

  @override
  State<_CurrentStepSegment> createState() => _CurrentStepSegmentState();
}

class _CurrentStepSegmentState extends State<_CurrentStepSegment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
