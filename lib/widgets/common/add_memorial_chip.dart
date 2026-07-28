import 'package:flutter/material.dart';

/// 添加纪念日事项按钮（浅灰底 + 实线描边）
class AddMemorialChip extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const AddMemorialChip({
    super.key,
    required this.onTap,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final radius = size >= 36 ? 10.0 : 7.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F1F4),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: const Color(0xFFD8DADD)),
        ),
        child: Icon(
          Icons.add,
          size: size * 0.5,
          color: Colors.black,
        ),
      ),
    );
  }
}
