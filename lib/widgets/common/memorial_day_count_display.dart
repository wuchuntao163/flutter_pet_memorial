import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../l10n/tr.dart';
import '../../models/font_style_config.dart';
import '../../models/memorial_day.dart';
import 'day_number_display.dart';

/// 倒数日详情 / 存为图片预览共用的天数字号
class MemorialDayCountStyle {
  MemorialDayCountStyle._();

  static const double digitHeight = 72;
  static const double fontSize = 60;
  static const double suffixFontSize = 20;
  static const double suffixBottomPadding = 10;

  static TextStyle textStyle({Color? color}) => TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: color ?? AppColors.textPrimary,
        letterSpacing: -2,
        height: 1,
      );

  static TextStyle unitStyle(TextStyle base) => base.copyWith(
        fontSize: suffixFontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: 0,
        color: base.color,
      );
}

/// 详情页天数展示（支持纯天/周+天/月+天/年+月+天）
class MemorialDayCountDisplay extends StatelessWidget {
  final MemorialDay memorialDay;
  final TextStyle? textStyle;
  final double digitHeight;
  final double? unitFontSize;
  final bool scaleToFit;

  const MemorialDayCountDisplay({
    super.key,
    required this.memorialDay,
    this.textStyle,
    this.digitHeight = MemorialDayCountStyle.digitHeight,
    this.unitFontSize,
    this.scaleToFit = false,
  });

  @override
  Widget build(BuildContext context) {
    return _wrapScaleToFit(context, _buildContent());
  }

  Widget _wrapScaleToFit(BuildContext context, Widget child) {
    if (!scaleToFit) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;

        return SizedBox(
          width: maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final baseStyle = textStyle ?? MemorialDayCountStyle.textStyle();
    final unitStyle = MemorialDayCountStyle.unitStyle(baseStyle).copyWith(
      fontSize: unitFontSize ?? MemorialDayCountStyle.suffixFontSize,
    );
    final digitUrls = FontStyleConfig.digitImageUrls(memorialDay.fontStyleId);
    final useImageDigits =
        digitUrls != null && !FontStyleConfig.isNormalStyle(memorialDay.fontStyleId);

    if (memorialDay.dayCountDisplayMode == DayCountDisplayMode.days) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          useImageDigits
              ? DayNumberDisplay(
                  value: memorialDay.displayDayCount,
                  fontStyleId: memorialDay.fontStyleId,
                  digitHeight: digitHeight,
                  textStyle: baseStyle,
                )
              : Text('${memorialDay.displayDayCount}', style: baseStyle),
          _buildUnitText(tr('common.unit_day'), unitStyle),
        ],
      );
    }

    if (useImageDigits) {
      return _buildSegmentRow(
        memorialDay.dayCountDisplaySegments,
        baseStyle,
        unitStyle: unitStyle,
        imageDigits: true,
      );
    }

    return _buildSegmentRow(
      memorialDay.dayCountDisplaySegments,
      baseStyle,
      unitStyle: unitStyle,
      imageDigits: false,
    );
  }

  Widget _buildUnitText(String unit, TextStyle unitStyle) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: MemorialDayCountStyle.suffixBottomPadding,
      ),
      child: Text(unit, style: unitStyle),
    );
  }

  Widget _buildSegmentRow(
    List<DayCountDisplaySegment> segments,
    TextStyle baseStyle, {
    required TextStyle unitStyle,
    required bool imageDigits,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < segments.length; i++)
          if (segments[i].isNumber)
            imageDigits
                ? DayNumberDisplay(
                    value: segments[i].number!,
                    fontStyleId: memorialDay.fontStyleId,
                    digitHeight: digitHeight,
                    textStyle: baseStyle,
                  )
                : Text('${segments[i].number}', style: baseStyle)
          else
            Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 2,
                right: 2,
              ),
              child: _buildUnitText(segments[i].unit!, unitStyle),
            ),
      ],
    );
  }
}

/// 选择数字样式弹窗内的预览
class MemorialDayCountStylePreview extends StatelessWidget {
  final MemorialDay memorialDay;
  final String fontStyleId;
  final double digitHeight;
  final TextStyle? textStyle;

  const MemorialDayCountStylePreview({
    super.key,
    required this.memorialDay,
    this.fontStyleId = FontStyleConfig.normalStyleId,
    this.digitHeight = 46,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = textStyle ??
        const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          letterSpacing: -1,
          height: 1.15,
        );
    final previewNumber = memorialDay.digitalDisplayNumber;
    final useImageDigits =
        FontStyleConfig.digitImageUrls(fontStyleId) != null &&
        !FontStyleConfig.isNormalStyle(fontStyleId);

    if (useImageDigits) {
      return DayNumberDisplay(
        value: previewNumber,
        fontStyleId: fontStyleId,
        digitHeight: digitHeight,
        textStyle: baseStyle,
      );
    }

    return Text(
      '$previewNumber',
      style: baseStyle,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
    );
  }
}
