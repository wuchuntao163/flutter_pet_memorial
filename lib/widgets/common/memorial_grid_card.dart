import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../config/layout.dart';
import '../../l10n/tr.dart';
import '../../utils/date_format_util.dart';
import '../../models/memorial_day.dart';
import '../../utils/lunar_calendar_util.dart';
import 'memorial_type_info.dart';

/// 首页纪念事项网格卡片（对齐设计稿）
class MemorialGridCard extends StatelessWidget {
  final MemorialDay memorialDay;
  final VoidCallback? onTap;

  const MemorialGridCard({
    super.key,
    required this.memorialDay,
    this.onTap,
  });

  static const _cardRadius = 20.0;
  static const _insetH = AppLayout.memorialGridCardInsetH;
  static const _titleColor = Color(0xFF5C4033);
  Color get _bgColor => MemorialTypeInfo.daysBackground(memorialDay);

  Color get _countColor => MemorialTypeInfo.daysText(memorialDay);

  String get _headerText =>
      '${memorialDay.title}${memorialDay.gridStatusSuffix}';

  String get _yearLine {
    if (memorialDay.calendarType == CalendarType.lunar) {
      return LunarCalendarUtil.formatLunarYearLine(
        year: memorialDay.date.year,
        month: memorialDay.date.month,
        day: memorialDay.date.day,
        isLeapMonth: memorialDay.isLunarLeapMonth,
      );
    }
    return DateFormatUtil.formatSolarYear(memorialDay.date.year);
  }

  String get _monthDayLine {
    if (memorialDay.calendarType == CalendarType.lunar) {
      return LunarCalendarUtil.formatLunarMonthDayLine(
        year: memorialDay.date.year,
        month: memorialDay.date.month,
        day: memorialDay.date.day,
        isLeapMonth: memorialDay.isLunarLeapMonth,
      );
    }
    return DateFormatUtil.formatSolarMonthDay(
      month: memorialDay.date.month,
      day: memorialDay.date.day,
    );
  }

  static const _pinWidth = 16.0;
  static const _pinHeight = 22.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Container(
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: _countColor.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned(
                    top: AppLayout.memorialGridTitleTopInset,
                    left: _insetH,
                    right: _insetH,
                    child: Text(
                      _headerText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppLayout.memorialGridTitleFontSize,
                        fontWeight: FontWeight.w600,
                        color: _titleColor,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Positioned(
                    left: _insetH,
                    right: _insetH,
                    top: AppLayout.memorialGridTitleTopInset +
                        AppLayout.memorialGridDayCountTopGap,
                    bottom: AppLayout.memorialGridBottomInset +
                        AppLayout.memorialGridDayCountBottomGap,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildDayCount(),
                    ),
                  ),
                  Positioned(
                    left: _insetH,
                    right: _insetH,
                    bottom: AppLayout.memorialGridBottomInset,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _yearLine,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                                height: 1.25,
                              ),
                            ),
                            Text(
                              _monthDayLine,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        MemorialTypeInfo.icon(
                          memorialDay,
                          size: AppLayout.memorialGridTypeIconSize,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (memorialDay.isPinned)
            Positioned(
              top: -_pinHeight / 2,
              right: 10,
              child: Image.asset(
                'assets/images/image_47.png',
                width: _pinWidth,
                height: _pinHeight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayCount() {
    final countText = '${memorialDay.displayDayCount}';
    final countFontSize = AppLayout.memorialGridDayCountFontSize;
    final countStyle = TextStyle(
      fontSize: countFontSize,
      fontWeight: FontWeight.bold,
      color: _countColor,
      height: 1,
      letterSpacing: -0.5,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(countText, style: countStyle),
        const SizedBox(width: 2),
        Text(
          tr('common.unit_day'),
          style: TextStyle(
            fontSize: AppLayout.memorialGridDayUnitFontSize,
            fontWeight: FontWeight.w600,
            color: _countColor.withValues(alpha: 0.88),
            height: 1,
          ),
        ),
      ],
    );
  }
}
