import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api/api.dart';
import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../data/memorial_store.dart';
import '../../data/background_store.dart';
import '../../models/background_style_config.dart';
import '../../models/font_style_config.dart';
import '../../models/memorial_day.dart';
import '../../router/app_routes.dart';
import '../../utils/center_tip_util.dart';
import '../../utils/date_format_util.dart';
import '../../utils/lunar_calendar_util.dart';
import '../../widgets/common/memorial_type_info.dart';
import '../../widgets/common/compact_app_bar.dart';
import '../../widgets/common/memorial_day_count_display.dart';
import '../../widgets/dialogs/background_style_dialog.dart';
import '../../widgets/menus/memorial_detail_action_menu.dart';
import '../../app.dart';
import '../../l10n/tr.dart';

/// 纪念日天数详情（设计稿：倒计时 + 日期 + 样式）
class MemorialDayDetailScreen extends StatefulWidget {
  final MemorialDay memorialDay;

  const MemorialDayDetailScreen({super.key, required this.memorialDay});

  @override
  State<MemorialDayDetailScreen> createState() =>
      _MemorialDayDetailScreenState();
}

class _MemorialDayDetailScreenState extends State<MemorialDayDetailScreen> {
  @override
  void initState() {
    super.initState();
    MemorialStore.instance.addListener(_onStoreChanged);
    BackgroundStore.instance.addListener(_onStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDefaultBackground());
  }

  @override
  void dispose() {
    MemorialStore.instance.removeListener(_onStoreChanged);
    BackgroundStore.instance.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    _ensureDefaultBackground();
    if (mounted) setState(() {});
  }

  void _ensureDefaultBackground() {
    final day = _day;
    if (day.backgroundStyleId.isNotEmpty) return;
    MemorialStore.instance.update(
      day.copyWith(
        backgroundStyleId: BackgroundStyleConfig.typeColorStyleId,
      ),
    );
  }

  MemorialDay get _day =>
      MemorialStore.instance.findById(widget.memorialDay.id) ??
      widget.memorialDay;

  Future<void> _showActionMenu() async {
    final action = await MemorialDetailActionMenu.show(context);
    if (!mounted || action == null) return;

    switch (action) {
      case MemorialDetailAction.edit:
        await context.push(AppRoutes.memorialEdit(_day.id));
        break;
      case MemorialDetailAction.saveImage:
      case MemorialDetailAction.share:
        await context.push(AppRoutes.memorialOverview(_day.id));
        break;
      case MemorialDetailAction.delete:
        await _confirmDelete();
        break;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('memorial.delete_title')),
        content: Text(
          '${tr('memorial.delete_prefix')}${_day.title}${tr('memorial.delete_suffix')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr('common.delete'),
              style: const TextStyle(color: AppColors.delete),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final msg =
            await MemorialStore.instance.deleteAnniversary(_day.id);
        if (!mounted) return;
        showCenterTip(context, msg);
        context.pop();
      } on ApiException catch (e) {
        if (!mounted) return;
        showCenterTip(context, e.message);
      }
    }
  }

  void _cycleDayCountMode() {
    final day = _day;
    final next = day.nextDayCountDisplayMode;
    if (next == null) return;
    MemorialStore.instance.update(
      day.copyWith(dayCountDisplayMode: next),
    );
  }

  void _pickNumberStyle() {
    showNumberStyleDialog(
      context,
      memorialDay: _day,
      initialStyleId: _day.fontStyleId,
      onConfirm: (styleId) {
        MemorialStore.instance.update(_day.copyWith(fontStyleId: styleId));
      },
    );
  }

  void _pickBackgroundStyle() {
    showDialog(
      context: context,
      builder: (context) => BackgroundStyleDialog(
        memorialDay: _day,
        initialStyleId: _day.backgroundStyleId,
        onConfirm: (selection) {
          MemorialStore.instance.update(
            _day.copyWith(
              backgroundTab: selection.categoryId ?? '',
              backgroundStyleId: selection.styleId,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final typeColor = MemorialTypeInfo.daysText(day);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: CompactAppBar(
        title: day.title,
        showBackText: true,
        showActions: true,
        topPadding: AppLayout.memorialDetailTopPadding,
        onMore: _showActionMenu,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          16,
          AppLayout.memorialDetailTopPadding,
          16,
          12,
        ),
        child: Column(
          children: [
            _buildCountdownCard(day, typeColor),
            const SizedBox(height: 10),
            _buildDateCard(day, typeColor),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickBackgroundStyle,
                    child: _buildStyleCard(
                      label: tr('birthday.bg_style'),
                      icon: Icons.palette_outlined,
                      value: BackgroundStyleConfig.labelFor(
                        day.backgroundStyleId,
                        day: day,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickNumberStyle,
                    child: _buildStyleCard(
                      label: tr('birthday.num_style'),
                      icon: Icons.text_fields,
                      value: FontStyleConfig.labelFor(day.fontStyleId),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownCard(MemorialDay day, Color typeColor) {
    return Container(
      height: AppLayout.memorialDetailCountdownHeight,
      decoration: BackgroundStyleConfig.cardDecoration(
        day.backgroundStyleId,
        day: day,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.statusLabel,
                  style: TextStyle(
                    fontSize: AppLayout.memorialDetailCountdownStatusFontSize,
                    fontWeight: FontWeight.w600,
                    color: typeColor,
                  ),
                ),
                const SizedBox(
                  height: AppLayout.memorialDetailCountdownStatusGap,
                ),
                GestureDetector(
                  onTap: day.canCycleDayCountDisplayMode
                      ? _cycleDayCountMode
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: MemorialDayCountDisplay(
                    memorialDay: day,
                    textStyle: MemorialDayCountStyle.textStyle().copyWith(
                      fontSize: AppLayout.memorialDetailCountdownFontSize,
                    ),
                    digitHeight: AppLayout.memorialDetailCountdownDigitHeight,
                    unitFontSize: AppLayout.memorialDetailCountdownUnitFontSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(MemorialDay day, Color typeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: AppLayout.memorialDetailDateCardPaddingV,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MemorialTypeInfo.icon(
                day,
                size: AppLayout.memorialDetailDateCardIconSize,
                color: typeColor,
              ),
              const SizedBox(width: 6),
              Text(
                MemorialTypeInfo.label(day),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: typeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            day.monthAbbr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: MemorialTypeInfo.daysBackground(day),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.displayDayNumber}',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            day.weekdayLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 6),
          Text(
            day.calendarType == CalendarType.lunar
                ? LunarCalendarUtil.formatLunarYearLine(
                    year: day.date.year,
                    month: day.date.month,
                    day: day.date.day,
                    isLeapMonth: day.isLunarLeapMonth,
                  )
                : DateFormatUtil.formatSolarYear(day.date.year),
            style: const TextStyle(
              fontSize: AppLayout.memorialDetailDateCardYearFontSize,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleCard({
    required String label,
    required IconData icon,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMedium),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.accentDark),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
