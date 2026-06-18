import 'package:flutter/material.dart';

/// 渐变/纯色可点击按钮。
class GradientTapButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final BoxBorder? border;
  final Widget child;

  const GradientTapButton({
    super.key,
    required this.onTap,
    required this.child,
    this.gradient,
    this.color,
    this.borderRadius = 12,
    this.padding,
    this.width,
    this.height,
    this.alignment,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        alignment: alignment ?? (height != null ? Alignment.center : null),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? color : null,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
        ),
        child: child,
      ),
    );
  }
}
