import 'package:flutter/material.dart';
import '../../config/colors.dart';

class SettingsItem extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showArrow;

  const SettingsItem({
    super.key,
    this.icon,
    this.iconAsset,
    required this.title,
    this.trailing,
    this.onTap,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          border: Border.all(color: AppColors.borderLight),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: iconAsset != null
                    ? Image.asset(
                        iconAsset!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      )
                    : Icon(icon, size: 24, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            ?trailing,
            if (showArrow)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

class SwitchSettingsItem extends StatelessWidget {
  final IconData? icon;
  final String? iconAsset;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SwitchSettingsItem({
    super.key,
    this.icon,
    this.iconAsset,
    required this.title,
    required this.value,
    this.onChanged,
  }) : assert(icon != null || iconAsset != null);

  @override
  Widget build(BuildContext context) {
    return SettingsItem(
      icon: icon,
      iconAsset: iconAsset,
      title: title,
      trailing: GestureDetector(
        onTap: () => onChanged?.call(!value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: value ? AppColors.switchOn : AppColors.switchOff,
          ),
          padding: EdgeInsets.only(
            left: value ? 20 : 2,
            right: value ? 2 : 20,
            top: 2,
            bottom: 2,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.bgWhite,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
