import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/app_cache_store.dart';
import '../../l10n/tr.dart';
import '../../router/app_routes.dart';
import '../../services/language_service.dart';
import '../../utils/banner_util.dart';

/// 底部导航（完全走接口 `/api/common/nav?type=2`；「组件」仅 iOS 可见）
class BottomNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavBar({super.key, required this.navigationShell});

  static const _barHeight = 55.0;
  static const _barRadius = 29.0;

  static const _fallback = [
    {'name': '', 'url': AppRoutes.home, 'icon': ''},
    {'name': '', 'url': AppRoutes.profile, 'icon': ''},
  ];

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

  static bool _isHttpIcon(String icon) {
    final value = icon.trim().toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// 接口菜单顺序；无数据时用日子/我的兜底。「组件」仅 iOS。
  static List<dynamic> _buildItems(List<dynamic> apiItems) {
    final source = apiItems.isNotEmpty ? apiItems : _fallback;
    return source.where((raw) {
      if (raw is! Map) return true;
      final map = Map<String, dynamic>.from(raw);
      if (!BannerUtil.shouldShowOnCurrentPlatform(map)) return false;
      final path = _normalizePath(map['url']?.toString() ?? '');
      // 组件页依赖 iOS 小组件 / 灵动岛，Android 不展示该 Tab
      if (path == AppRoutes.component && !Platform.isIOS) return false;
      return true;
    }).toList();
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
                decoration: BoxDecoration(
                  color: AppColors.bgWhite,
                  borderRadius: BorderRadius.circular(_barRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 5,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_barRadius),
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
    final fallbackIcon = Icon(fallback, size: 26, color: fallbackColor);

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
            if (icon.isNotEmpty && _isHttpIcon(icon))
              Image.network(
                icon,
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) => fallbackIcon,
              )
            else if (icon.isNotEmpty)
              Image.asset(
                'assets/images/$icon',
                width: 28,
                height: 28,
                errorBuilder: (_, _, _) => fallbackIcon,
              )
            else
              fallbackIcon,
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
