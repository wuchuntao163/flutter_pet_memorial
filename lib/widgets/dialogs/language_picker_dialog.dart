import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../data/app_cache_store.dart';
import '../../l10n/tr.dart';
import '../../services/language_service.dart';
import '../../utils/center_tip_util.dart';

/// 切换语言：列表来自 getLanguage，选中项缓存 font_name 并拉取语言包
class LanguagePickerDialog extends StatelessWidget {
  const LanguagePickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const LanguagePickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) => _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final list = AppCacheStore.instance.languageList;
    final current = LanguageService.instance.fontName;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 360),
        decoration: BoxDecoration(
          color: AppColors.bgWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                tr('language.title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('language.empty_list'),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    if (item is! Map) return const SizedBox.shrink();
                    final title = item['title']?.toString() ?? '';
                    final code = item['font_name']?.toString() ?? '';
                    final selected = code.isNotEmpty && code == current;

                    return ListTile(
                      title: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check,
                              color: AppColors.accent,
                              size: 20,
                            )
                          : null,
                      onTap: code.isEmpty
                          ? null
                          : () => _onSelect(context, code),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    tr('common.cancel'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSelect(BuildContext context, String code) async {
    try {
      await LanguageService.instance.switchTo(code);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      showCenterTip(context, '${tr('language.switch_failed')}$e');
    }
  }
}
