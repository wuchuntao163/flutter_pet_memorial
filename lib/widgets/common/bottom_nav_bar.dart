import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../l10n/tr.dart';
import '../../router/app_routes.dart';
import '../../services/language_service.dart';
import '../../services/pet_image_service.dart';
import '../../widgets/common/app_logo.dart';

/// 底部导航（数据来自 getNav type=2）
class BottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavBar({super.key, required this.navigationShell});

  static const _barHeight = 55.0;
  static const _barRadius = 29.0;

  static const _fallback = [
    {'name': '', 'url': AppRoutes.home, 'icon': ''},
    {'name': '', 'url': AppRoutes.profile, 'icon': ''},
  ];

  /// 接口 name（如「日子」「我的」）→ nav.{name} 双语文案
  static String _localizedNavName(String rawName) {
    final key = rawName.trim();
    if (key.isEmpty) return key;
    return tr('nav.$key', fb: key);
  }

  static String _fallbackName(String url) {
    final path = url.split('?').first;
    if (path == AppRoutes.profile) return tr('nav.我的', fb: '我的');
    return tr('nav.日子', fb: '日子');
  }

  static int branchIndexForUrl(String url) {
    final path = url.split('?').first;
    if (path == AppRoutes.profile) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppCacheStore.instance,
        LanguageService.instance,
      ]),
      builder: (context, _) {
        final items = AppCacheStore.instance.navList.isNotEmpty
            ? AppCacheStore.instance.navList
            : _fallback;
        final currentIndex = navigationShell.currentIndex;

        return Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                AppLayout.bottomNavBarBottomGap,
              ),
              child: Container(
                height: _barHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(_barRadius),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _item(context, items[i], i, currentIndex),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _item(
    BuildContext context,
    dynamic raw,
    int listIndex,
    int currentIndex,
  ) {
    final map = raw is Map ? raw : const {};
    final url = map['url']?.toString() ?? '';
    final rawName = map['name']?.toString() ?? '';
    final name = rawName.isNotEmpty
        ? _localizedNavName(rawName)
        : (url.isEmpty ? '' : _fallbackName(url));
    final branchIndex = url.isEmpty ? listIndex : branchIndexForUrl(url);
    final active = currentIndex == branchIndex;
    final icon = map['icon']?.toString() ?? '';
    final iconUrl = icon.isEmpty ? '' : PetImageService.resolveUrl(icon);
    final textColor = AppColors.accentDark;

    return GestureDetector(
      onTap: url.isEmpty
          ? null
          : () {
              if (navigationShell.currentIndex == branchIndex) return;
              navigationShell.goBranch(branchIndex, initialLocation: true);
            },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF8A59B) : Colors.transparent,
          borderRadius: BorderRadius.circular(_barRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconUrl.isNotEmpty)
              Image.network(
                iconUrl,
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) => const AppLogo(size: 28),
              )
            else
              const AppLogo(size: 28),
            const SizedBox(height: 0),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
