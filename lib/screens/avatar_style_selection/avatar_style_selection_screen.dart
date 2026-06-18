import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/avatar_style_store.dart';
import '../../l10n/tr.dart';
import '../../utils/center_tip_util.dart';
import '../../router/app_routes.dart';
import '../../widgets/common/gradient_tap_button.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/dialogs/avatar_generation_dialog.dart';
import '../../widgets/dialogs/avatar_style_picker_dialog.dart';

/// 选择 AI 生成风格（全屏页面），下一步打开生成虚拟形象弹窗。
class AvatarStyleSelectionScreen extends StatefulWidget {
  const AvatarStyleSelectionScreen({super.key});

  @override
  State<AvatarStyleSelectionScreen> createState() =>
      _AvatarStyleSelectionScreenState();
}

class _AvatarStyleSelectionScreenState extends State<AvatarStyleSelectionScreen> {
  List<AvatarGenerationStyle> _styles = const [];
  String? _selectedId;
  bool _loadingStyles = true;

  @override
  void initState() {
    super.initState();
    _loadStyles();
  }

  Future<void> _loadStyles() async {
    try {
      final styles = await AvatarStyleStore.fetchStyles();
      if (!mounted) return;
      setState(() {
        _styles = styles;
        _selectedId = styles.isNotEmpty ? styles.first.id : null;
        _loadingStyles = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loadingStyles = false);
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingStyles = false);
      _showMessage('$e');
    }
  }

  AvatarGenerationStyle? get _selectedStyle {
    final selectedId = _selectedId;
    if (selectedId == null) return null;
    for (final style in _styles) {
      if (style.id == selectedId) return style;
    }
    return null;
  }

  Future<void> _onNext() async {
    final style = _selectedStyle;
    if (style == null) return;

    final result = await showAvatarGenerationDialog(
      context,
      selectedStyleId: style.id,
      selectedStyleName: style.name,
    );
    if (!mounted || result == null) return;
    context.push(AppRoutes.petNaming('custom'));
  }

  void _showMessage(String text) {
    showCenterTip(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: AppLayout.memorialAddTopPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      behavior: HitTestBehavior.opaque,
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
                              color: AppColors.accentDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(child: AppLogo(size: 56)),
                    SizedBox(
                      height: AppLayout.memorialAddTitleHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tr('avatar.style_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgWhite,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      Text(
                        tr('avatar.style_subtitle'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF5C4033),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('avatar.style_hint'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF5C4033),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _loadingStyles
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              )
                            : _styles.isEmpty
                                ? Center(
                                    child: Text(
                                      tr('avatar.style_empty'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                    ),
                                    itemCount: _styles.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 0.88,
                                    ),
                                    itemBuilder: (context, index) {
                                      final style = _styles[index];
                                      return AvatarStyleGridItem(
                                        style: style,
                                        selected: style.id == _selectedId,
                                        onTap: () => setState(
                                          () => _selectedId = style.id,
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Center(child: _buildNextButton()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final enabled = !_loadingStyles && _styles.isNotEmpty;
    return GradientTapButton(
      onTap: enabled ? _onNext : null,
      gradient: enabled ? AppColors.avatarGenerateGradient : null,
      color: enabled ? null : AppColors.borderMedium,
      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 11),
      child: Text(
        tr('avatar.style_next'),
        style: TextStyle(
          fontSize: 15,
          height: 1,
          color: enabled
              ? AppColors.avatarGenerateButtonText
              : AppColors.textTertiary,
        ),
      ),
    );
  }
}
