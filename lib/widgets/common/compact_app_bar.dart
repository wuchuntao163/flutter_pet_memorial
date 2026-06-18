import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../l10n/tr.dart';

/// 与设计稿一致的紧凑顶栏：返回 / 标题 / 更多
class CompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackText;
  final bool showLeading;
  final bool showActions;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final double topPadding;

  const CompactAppBar({
    super.key,
    required this.title,
    this.showBackText = false,
    this.showLeading = true,
    this.showActions = true,
    this.topPadding = 0,
    this.onBack,
    this.onMore,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        AppLayout.memorialDetailAppBarHeight + topPadding,
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: AppLayout.memorialDetailAppBarHeight + topPadding,
      titleSpacing: 0,
      actionsPadding: EdgeInsets.zero,
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leadingWidth: showLeading ? (showBackText ? 72 : 44) : 0,
      leading: showLeading
          ? (showBackText
                ? GestureDetector(
                    onTap: onBack ?? () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 12,
                        top: topPadding,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back_ios_new,
                            size: 14,
                            color: AppColors.accentDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            tr('common.back'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentDark.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: AppColors.accentDark,
                      ),
                      onPressed: onBack ?? () => context.pop(),
                    ),
                  ))
          : null,
      title: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.accentDark,
          ),
        ),
      ),
      actions: showActions
          ? [
              Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: IconButton(
                padding: const EdgeInsets.only(right: 8),
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: AppColors.accentDark,
                ),
                onPressed: onMore ?? () {},
                ),
              ),
            ]
          : null,
    );
  }
}
