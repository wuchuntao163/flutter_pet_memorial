import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../utils/banner_util.dart';
/// 我的页 Banner 轮播
class ProfileBanner extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const ProfileBanner({super.key, required this.items});

  @override
  State<ProfileBanner> createState() => _ProfileBannerState();
}

class _ProfileBannerState extends State<ProfileBanner> {
  static const _height = 72.0;

  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onBannerTap(Map<String, dynamic> item) async {
    await BannerUtil.onBannerTap(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    if (items.length == 1) {
      return _buildBannerItem(items.first);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (_, index) => _buildBannerItem(items[index]),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            final active = index == _currentIndex;
            return Container(
              width: active ? 14 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.accent
                    : AppColors.accent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildBannerItem(Map<String, dynamic> item) {
    final imageUrl = item['image_url']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _onBannerTap(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          width: double.infinity,
          height: _height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            height: _height,
            color: const Color(0xFFF9FAFB),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
