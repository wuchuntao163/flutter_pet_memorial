import 'package:flutter/material.dart';
import '../../config/colors.dart';

class ActionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;
  final double borderRadius;
  final String? iconAsset;
  final Widget? icon;

  const ActionButton({
    super.key,
    required this.text,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.height,
    this.borderRadius = 12,
    this.iconAsset,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? 44,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.accent,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconAsset != null) ...[
              Image.asset(iconAsset!, width: 16, height: 16),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 6),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor ?? AppColors.accentDarker,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
