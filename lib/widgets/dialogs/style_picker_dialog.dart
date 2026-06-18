import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../data/app_cache_store.dart';
import '../../l10n/tr.dart';
import '../common/pet_profile_decor_image.dart';

/// 背景样式 / 数字样式等选择弹窗的统一样式
class StylePickerDialog extends StatelessWidget {
  final String title;
  final Widget body;
  final VoidCallback onConfirm;
  final Widget? fullWidthTop;
  final EdgeInsetsGeometry bodyPadding;

  const StylePickerDialog({
    super.key,
    required this.title,
    required this.body,
    required this.onConfirm,
    this.fullWidthTop,
    this.bodyPadding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppCacheStore.instance,
      builder: (context, _) {
        final decorUrl = AppCacheStore.instance.petProfileTwo;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Header(title: title),
                    ?fullWidthTop,
                    Padding(
                      padding: bodyPadding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          body,
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _ActionButtons(onConfirm: onConfirm),
                    ),
                  ],
                ),
              ),
              if (decorUrl != null)
                Positioned(
                  top: -62,
                  right: 20,
                  child: PetProfileDecorImage(
                    url: decorUrl,
                    width: 72,
                    height: 72,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static const numberStyleGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 1.55,
  );

  static const backgroundStyleGridDelegate = numberStyleGridDelegate;

  static Widget rectGridTile({
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    const radius = 8.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: isSelected ? AppColors.modalHeader : const Color(0xFFF3F4F6),
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }

}

class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.modalHeaderBg,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.modalHeaderText,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.close,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onConfirm;

  const _ActionButtons({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                tr('common.cancel'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.modalHeader,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                tr('common.confirm'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.avatarGenerateButtonText,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
