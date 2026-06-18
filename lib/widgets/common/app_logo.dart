import 'package:flutter/material.dart';

/// 应用 Logo（assets/images/logo.png）
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 72,
    this.fit = BoxFit.contain,
  });

  static const assetPath = 'assets/images/logo.png';

  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (_, _, _) => Icon(
        Icons.pets,
        size: size * 0.7,
        color: const Color(0xFFFFB2A6),
      ),
    );
  }
}
