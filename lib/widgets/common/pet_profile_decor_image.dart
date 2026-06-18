import 'package:flutter/material.dart';

import '../../services/pet_image_service.dart';
import 'pet_avatar_image.dart';

/// getPetProfileInfo 装饰图（one / two 等），无 URL 时不占位
class PetProfileDecorImage extends StatelessWidget {
  final String? url;
  final double width;
  final double height;

  const PetProfileDecorImage({
    super.key,
    required this.url,
    this.width = 85,
    this.height = 85,
  });

  @override
  Widget build(BuildContext context) {
    final raw = url?.trim() ?? '';
    if (raw.isEmpty) return const SizedBox.shrink();

    return PetAvatarImage(
      url: PetImageService.resolveUrl(raw),
      width: width,
      height: height,
    );
  }
}
