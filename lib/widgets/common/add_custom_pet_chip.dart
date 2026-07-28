import 'package:flutter/material.dart';

import '../../config/colors.dart';

/// 选择宠物列表中的「+」：引导生成自家宠物虚拟形象
class AddCustomPetChip extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const AddCustomPetChip({
    super.key,
    required this.onTap,
    this.size = 66,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFF1F2F5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          size: size * 0.42,
          color: AppColors.textPlaceholder,
        ),
      ),
    );
  }
}
