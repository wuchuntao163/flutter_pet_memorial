import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../l10n/tr.dart';
import '../../router/app_routes.dart';
import '../../services/language_service.dart';

/// 底部导航（接口菜单 + 前端固定的组件菜单）
class BottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavBar({super.key, required this.navigationShell});

  static const _barHeight = 55.0;
  static const _barRadius = 29.0;

  static const _fallback = [
    {'name': '', 'url': AppRoutes.home, 'icon': ''},
    {'name': '', 'url': AppRoutes.profile, 'icon': ''},
  ];

  static const _componentItem = {
    'name': '组件',
    'url': AppRoutes.component,
    'icon': 'component.png',
  };

  /// 接口 name（如「日子」「我的」「组件」）→ nav.{name} 双语文案
  static String _localizedNavName(String rawName) {
    final key = rawName.trim();
    if (key.isEmpty) return key;
    return tr('nav.$key', fb: key);
  }

  static String _fallbackName(String url) {
    final path = _normalizePath(url);
    if (path == AppRoutes.profile) return tr('nav.我的', fb: '我的');
    if (path == AppRoutes.component) return tr('nav.组件', fb: '组件');
    return tr('nav.日子', fb: '日子');
  }

  static String _normalizePath(String url) {
    final path = url.split('?').first.trim();
    if (path.isEmpty) return path;
    return path.startsWith('/') ? path : '/$path';
  }

  /// url → StatefulShell 分支下标（与 app_router 中 branches 顺序一致）
  static int? shellBranchIndexForUrl(String url) {
    final path = _normalizePath(url);
    if (path == AppRoutes.home) return 0;
    if (path == AppRoutes.profile) return 1;
    if (path == AppRoutes.component) return 2;
    return null;
  }

  static List<dynamic> _buildItems(List<dynamic> apiItems) {
    final items = apiItems.isNotEmpty ? apiItems : _fallback;
    return [
      _componentItem,
      ...items.where((raw) {
        if (raw is! Map) return true;
        return _normalizePath(raw['url']?.toString() ?? '') !=
            AppRoutes.component;
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppCacheStore.instance,
        LanguageService.instance,
      ]),
      builder: (context, _) {
        final items = _buildItems(AppCacheStore.instance.navList);
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
    final itemPath = _normalizePath(url);
    final branchIndex = url.isEmpty ? listIndex : shellBranchIndexForUrl(url);
    final active = branchIndex != null && currentIndex == branchIndex;

    final icon = map['icon']?.toString() ?? '';
    final textColor = AppColors.accentDark;
    final fallback = itemPath == AppRoutes.profile
        ? Icons.cloud
        : (itemPath == AppRoutes.component
              ? Icons.widgets_outlined
              : Icons.star_rounded);
    final fallbackColor = itemPath == AppRoutes.profile
        ? const Color(0xFFB8A0D9)
        : AppColors.blue;

    return GestureDetector(
      onTap: url.isEmpty || branchIndex == null
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
            if (itemPath == AppRoutes.component)
              Image.asset(
                'assets/images/$icon',
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) =>
                    Icon(fallback, size: 26, color: fallbackColor),
              )
            else if (icon.isNotEmpty)
              Image.network(
                icon,
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) =>
                    Icon(fallback, size: 26, color: fallbackColor),
              )
            else
              Icon(fallback, size: 26, color: fallbackColor),
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
