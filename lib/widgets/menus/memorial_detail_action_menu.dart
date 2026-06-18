import 'package:flutter/material.dart';
import '../../config/colors.dart';
import '../../l10n/tr.dart';

enum MemorialDetailAction { edit, saveImage, share, delete }

/// 倒数日详情页右上角操作菜单
class MemorialDetailActionMenu {
  MemorialDetailActionMenu._();

  static const _assetPrefix = 'assets/images/action_menu/';

  static Future<MemorialDetailAction?> show(BuildContext context) {
    // 紧贴 AppBar 下方，避免遮挡右上角三点按钮
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight - 8;

    return showGeneralDialog<MemorialDetailAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withOpacity(0.3),
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: top,
              right: 12,
              child: IntrinsicWidth(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 132),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: AppColors.bgWhite,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildMenuItem(
                          dialogContext,
                          '${_assetPrefix}ic_edit.png',
                          tr('detail_menu.edit'),
                          MemorialDetailAction.edit,
                        ),
                        _buildMenuItem(
                          dialogContext,
                          '${_assetPrefix}ic_save_image.png',
                          tr('detail_menu.save_image'),
                          MemorialDetailAction.saveImage,
                        ),
                        _buildMenuItem(
                          dialogContext,
                          '${_assetPrefix}ic_share.png',
                          tr('detail_menu.share'),
                          MemorialDetailAction.share,
                        ),
                        _buildMenuItem(
                          dialogContext,
                          '${_assetPrefix}ic_delete.png',
                          tr('detail_menu.delete'),
                          MemorialDetailAction.delete,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildMenuItem(
    BuildContext context,
    String icon,
    String label,
    MemorialDetailAction action, {
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.delete : AppColors.textPrimary;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop(action);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(icon, width: 18, height: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
