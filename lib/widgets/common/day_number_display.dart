import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../models/font_style_config.dart';
import '../../services/pet_image_service.dart';

class DayNumberDisplay extends StatelessWidget {
  final int value;
  final String fontStyleId;
  final TextStyle? textStyle;
  final double digitHeight;

  const DayNumberDisplay({
    super.key,
    required this.value,
    this.fontStyleId = FontStyleConfig.normalStyleId,
    this.textStyle,
    this.digitHeight = 52,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = textStyle ??
        const TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          letterSpacing: -2,
        );

    final digitUrls = FontStyleConfig.digitImageUrls(fontStyleId);
    if (digitUrls == null) {
      return Text('$value', style: baseStyle);
    }

    final digits = value.toString().split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final digit in digits)
          Image.network(
            PetImageService.resolveUrl(digitUrls[int.parse(digit)]),
            height: digitHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}
