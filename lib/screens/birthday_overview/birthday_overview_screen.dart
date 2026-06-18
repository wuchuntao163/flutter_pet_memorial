import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/background_store.dart';
import '../../data/memorial_store.dart';
import '../../models/background_style_config.dart';
import '../../data/font_style_store.dart';
import '../../models/font_style_config.dart';
import '../../models/memorial_day.dart';
import '../../utils/app_permission_util.dart';
import '../../utils/center_tip_util.dart';
import '../../widgets/common/gradient_tap_button.dart';
import '../../utils/memorial_image_saver.dart';
import '../../utils/memorial_share_service.dart';
import '../../widgets/common/memorial_day_count_display.dart';
import '../../l10n/tr.dart';
import '../../widgets/sheets/memorial_share_sheet.dart';

/// 纪念日个性化编辑（存为图片）
class BirthdayOverviewScreen extends StatefulWidget {
  final MemorialDay? memorialDay;

  const BirthdayOverviewScreen({super.key, this.memorialDay});

  @override
  State<BirthdayOverviewScreen> createState() => _BirthdayOverviewScreenState();
}

class _BirthdayOverviewScreenState extends State<BirthdayOverviewScreen> {
  final _previewKey = GlobalKey();
  final _previewTransformController = TransformationController();

  double _blurLevel = 0;
  String _fontColor = 'black';
  Color _autoTextColor = Colors.white;
  late String _previewFontStyleId;

  static const _autoColorPalette = [
    Colors.white,
    Colors.black,
    AppColors.accentDark,
    AppColors.blueText,
    AppColors.goldText,
    AppColors.orange,
    AppColors.textPrimary,
    Color(0xFF7C3AED),
    Color(0xFF059669),
  ];

  late String _backgroundStyleId;

  bool _isSaving = false;
  bool _isSharing = false;

  final _fontColors = ['white', 'black', 'auto'];

  @override
  void initState() {
    super.initState();
    final day = widget.memorialDay;
    _backgroundStyleId = day?.backgroundStyleId ?? '';
    _previewFontStyleId = day?.fontStyleId ?? FontStyleConfig.normalStyleId;
    MemorialStore.instance.addListener(_onStoreChanged);
    BackgroundStore.instance.addListener(_onStoreChanged);
    FontStyleStore.instance.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncDefaultBackground());
  }

  @override
  void dispose() {
    _previewTransformController.dispose();
    MemorialStore.instance.removeListener(_onStoreChanged);
    BackgroundStore.instance.removeListener(_onStoreChanged);
    FontStyleStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _syncDefaultBackground() {
    final day = _day;
    if (day == null) return;
    final effective = BackgroundStyleConfig.effectiveStyleId(
      _backgroundStyleId,
      day: day,
    );
    if (effective != _backgroundStyleId) {
      _backgroundStyleId = effective;
    }
  }

  void _onStoreChanged() {
    _syncDefaultBackground();
    if (mounted) setState(() {});
  }

  Color _pickRandomAutoColor() {
    final random = Random();
    return _autoColorPalette[random.nextInt(_autoColorPalette.length)];
  }

  void _selectFontColor(String color) {
    setState(() {
      _fontColor = color;
      if (color == 'auto') {
        _autoTextColor = _pickRandomAutoColor();
      }
    });
  }

  MemorialDay? get _day {
    final id = widget.memorialDay?.id;
    if (id != null) {
      return MemorialStore.instance.findById(id) ?? widget.memorialDay;
    }
    return widget.memorialDay;
  }

  Future<void> _save() async {
    final day = _day;
    if (day == null || _isSaving) return;

    setState(() => _isSaving = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    try {
      await MemorialImageSaver.saveRepaintBoundary(_previewKey);

      MemorialStore.instance.update(
        day.copyWith(
          backgroundStyleId: _backgroundStyleId,
          fontStyleId: _previewFontStyleId,
        ),
      );

      if (!mounted) return;
      context.pop();
      showCenterTip(context, tr('birthday.saved_to_album'));
    } on AppPermissionDeniedException catch (e) {
      if (!mounted) return;
      await AppPermissionUtil.showDeniedDialog(context, e);
    } catch (e) {
      if (!mounted) return;
      showCenterTip(context, '${tr('birthday.save_failed')}$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showShareSheet() async {
    if (_isSharing || _isSaving) return;

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await MemorialShareSheet.show(
      context,
      onShare: (target) async {
        setState(() => _isSharing = true);
        try {
          return await MemorialShareService.sharePreview(
            boundaryKey: _previewKey,
            target: target,
            sharePositionOrigin: origin,
          );
        } finally {
          if (mounted) setState(() => _isSharing = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: AppLayout.memorialDetailAppBarHeight +
                  AppLayout.memorialDetailTopPadding,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppLayout.memorialDetailTopPadding,
                  ),
                  child: SizedBox(
                    height: AppLayout.memorialDetailAppBarHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildBackButton(),
                        const Spacer(),
                        _buildShareButton(),
                        const SizedBox(width: 8),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  AppLayout.memorialDetailTopPadding,
                  16,
                  12,
                ),
                child: Column(
                  children: [
                    _buildPreviewCard(),
                    const SizedBox(height: 12),
                    _buildSettingsCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return GradientTapButton(
      onTap: _isSharing || _isSaving ? null : _showShareSheet,
      color: Colors.white,
      borderRadius: 8,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      child: _isSharing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.orange,
              ),
            )
          : Text(
              tr('birthday.share'),
              style: const TextStyle(
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
    );
  }

  Widget _buildSaveButton() {
    return GradientTapButton(
      onTap: _isSaving ? null : _save,
      color: const Color(0xFFFCD6A8),
      borderRadius: 8,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
          : Text(
              tr('birthday.save'),
              style: const TextStyle(
                fontSize: 13,
                height: 1,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
    );
  }

  Widget _buildBackButton() {
    return GradientTapButton(
      onTap: _isSaving ? null : () => context.pop(),
      color: AppColors.bgWhite,
      borderRadius: 8,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      border: Border.all(color: const Color(0xFFF3F4F6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.arrow_back_ios_new,
            size: 12,
            color: Color(0xFF333333),
          ),
          const SizedBox(width: 4),
          Text(
            tr('birthday.back'),
            style: const TextStyle(
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final day = _day;
    if (day == null) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFFDF6E9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              tr('birthday.no_data'),
              style: const TextStyle(color: AppColors.textTertiary),
            ),
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RepaintBoundary(
          key: _previewKey,
          child: _buildPreviewCardContent(day),
        ),
      ),
    );
  }

  Widget _buildPreviewCardContent(MemorialDay day) {
    final bgImage = SizedBox.expand(
      child: BackgroundStyleConfig.image(
        _backgroundStyleId,
        day: day,
      ),
    );

    final background = _blurLevel > 0
        ? ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _blurLevel * 10,
              sigmaY: _blurLevel * 10,
            ),
            child: bgImage,
          )
        : bgImage;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
            ClipRect(
              child: InteractiveViewer(
                transformationController: _previewTransformController,
                minScale: 1,
                maxScale: 4,
                clipBehavior: Clip.hardEdge,
                child: SizedBox.expand(child: background),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IgnorePointer(
                child: Column(
                children: [
                  const SizedBox(height: AppLayout.memorialSaveImageVerticalInset),
                  Text(
                    day.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _previewTextColor,
                    ),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(
                        0,
                        AppLayout.memorialSaveImageStatusOffset,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day.statusLabel,
                            style: TextStyle(
                              fontSize:
                                  AppLayout.memorialSaveImageStatusFontSize,
                              color: _previewSubtextColor,
                            ),
                          ),
                          const SizedBox(
                            height: AppLayout.memorialSaveImageStatusGap,
                          ),
                          MemorialDayCountDisplay(
                            memorialDay: day.copyWith(
                              fontStyleId: _previewFontStyleId,
                            ),
                            textStyle: MemorialDayCountStyle.textStyle(
                              color: _previewTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    day.formattedDateWithWeekday,
                    style: TextStyle(
                      fontSize: AppLayout.memorialSaveImageDateFontSize,
                      color: _previewSubtextColor,
                    ),
                  ),
                  const SizedBox(height: AppLayout.memorialSaveImageVerticalInset),
                ],
                ),
              ),
            ),
          ],
        ),
    );
  }

  Color get _previewTextColor {
    switch (_fontColor) {
      case 'white':
        return Colors.white;
      case 'auto':
        return _autoTextColor;
      default:
        return AppColors.textPrimary;
    }
  }

  Color get _previewSubtextColor {
    switch (_fontColor) {
      case 'white':
        return Colors.white.withValues(alpha: 0.85);
      case 'auto':
        return _autoTextColor.withValues(alpha: 0.85);
      default:
        return const Color(0xFF4B5563);
    }
  }

  Widget _buildSettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgWhite.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFF7ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(tr('birthday.blur_section')),
          const SizedBox(height: 8),
          _buildBlurSlider(),
          const SizedBox(height: 20),
          _buildSectionTitle(tr('birthday.color_section')),
          const SizedBox(height: 8),
          _buildFontColorSelector(),
          const SizedBox(height: 20),
          _buildSectionTitle(tr('birthday.font_section')),
          const SizedBox(height: 8),
          _buildFontStyleSelector(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4B5563),
      ),
    );
  }

  Widget _buildBlurSlider() {
    return Row(
      children: [
        Text(
          tr('birthday.blur_label'),
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _blurLevel,
              onChanged: (v) => setState(() => _blurLevel = v),
              activeColor: const Color(0xFF4B5563),
              inactiveColor: const Color(0xFFE5E7EB),
            ),
          ),
        ),
        Text(
          tr('birthday.clear_label'),
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _buildFontColorSelector() {
    final labels = [
      tr('birthday.color_white'),
      tr('birthday.color_black'),
      tr('birthday.color_auto'),
    ];
    return Row(
      children: List.generate(_fontColors.length, (i) {
        final color = _fontColors[i];
        final isSelected = color == _fontColor;
        return Expanded(
          child: GestureDetector(
            onTap: () => _selectFontColor(color),
            child: Container(
              height: 64,
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFDF5ED) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFFD9C7B6) : const Color(0xFFF3F4F6),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFontColorSwatch(color),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFontColorSwatch(String color) {
    const size = 24.0;

    if (color == 'auto') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: ClipOval(
          child: Row(
            children: [
              Expanded(child: Container(color: AppColors.bgWhite)),
              Expanded(child: Container(color: Colors.black)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == 'white' ? AppColors.bgWhite : Colors.black,
        border: color == 'white'
            ? Border.all(color: const Color(0xFFE5E7EB))
            : null,
      ),
    );
  }

  Widget _buildFontStyleSelector() {
    final day = _day;
    if (day == null) return const SizedBox.shrink();

    final items = FontStyleConfig.displayItems();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final styleId = '${item['id']}';
          final isSelected = _previewFontStyleId == styleId;
          final name =
              item['name']?.toString() ?? FontStyleConfig.labelFor(styleId);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildFontStyleTile(
              isSelected: isSelected,
              onTap: () => setState(() => _previewFontStyleId = styleId),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MemorialDayCountStylePreview(
                    memorialDay: day,
                    fontStyleId: styleId,
                    digitHeight: 32,
                    textStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.orange
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFontStyleTile({
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.orange : const Color(0xFFF3F4F6),
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
