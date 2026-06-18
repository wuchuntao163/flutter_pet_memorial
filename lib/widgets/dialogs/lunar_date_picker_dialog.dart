import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lunar/lunar.dart';

import '../../config/colors.dart';
import '../../config/fonts.dart';
import '../../l10n/tr.dart';
import '../../utils/date_format_util.dart';
import '../../utils/lunar_calendar_util.dart';

Future<LunarDateSelection?> showLunarDatePickerDialog(
  BuildContext context, {
  LunarDateSelection? initial,
}) {
  final now = DateTime.now();
  final fallback = LunarCalendarUtil.solarToLunar(now);
  initial ??= LunarDateSelection(
    year: fallback.year,
    month: fallback.month,
    day: fallback.day,
    isLeapMonth: fallback.isLeapMonth,
  );

  return showDialog<LunarDateSelection>(
    context: context,
    builder: (context) => _LunarDatePickerDialog(initial: initial!),
  );
}

class _LunarDatePickerDialog extends StatefulWidget {
  final LunarDateSelection initial;

  const _LunarDatePickerDialog({required this.initial});

  @override
  State<_LunarDatePickerDialog> createState() => _LunarDatePickerDialogState();
}

class _LunarDatePickerDialogState extends State<_LunarDatePickerDialog> {
  static final _years = [for (var y = 1970; y <= 2100; y++) y];

  static const _dayLabels = [
    '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
    '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
    '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十',
  ];

  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  late int _year;
  int _monthIndex = 0;
  late int _day;
  int _lastDayCount = 0;

  List<LunarMonth> _months = [];

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _day = widget.initial.day;
    _loadMonths();
    _monthIndex = _indexForMonth(
      widget.initial.month,
      widget.initial.isLeapMonth,
    );
    _clampDay();
    _lastDayCount = _dayCount;
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_year).clamp(0, _years.length - 1),
    );
    _monthController = FixedExtentScrollController(initialItem: _monthIndex);
    _dayController = FixedExtentScrollController(
      initialItem: (_day - 1).clamp(0, _dayCount - 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ready = true;
    });
  }

  void _resetDayControllerIfNeeded() {
    final count = _dayCount;
    if (count == _lastDayCount) return;
    _lastDayCount = count;
    _dayController.dispose();
    _dayController = FixedExtentScrollController(
      initialItem: (_day - 1).clamp(0, count - 1),
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _loadMonths() {
    _months = LunarYear.fromYear(_year).getMonths();
    if (_months.isNotEmpty && _monthIndex >= _months.length) {
      _monthIndex = 0;
    }
  }

  int _indexForMonth(int month, bool isLeapMonth) {
    for (var i = 0; i < _months.length; i++) {
      final m = _months[i];
      if (m.getMonth().abs() == month && m.isLeap() == isLeapMonth) return i;
    }
    return 0;
  }

  LunarMonth get _selectedMonth {
    if (_months.isEmpty) {
      return LunarYear.fromYear(_year).getMonths().first;
    }
    return _months[_monthIndex.clamp(0, _months.length - 1)];
  }

  int get _dayCount => _selectedMonth.getDayCount();

  void _clampDay() {
    final maxDay = _dayCount;
    if (_day > maxDay) _day = maxDay;
    if (_day < 1) _day = 1;
  }

  void _syncPickerPositions() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final yearIndex = _years.indexOf(_year);
      if (yearIndex >= 0 &&
          _yearController.hasClients &&
          _yearController.selectedItem != yearIndex) {
        _yearController.jumpToItem(yearIndex);
      }
      if (_monthController.hasClients &&
          _monthController.selectedItem != _monthIndex) {
        _monthController.jumpToItem(_monthIndex);
      }
      if (_dayController.hasClients) {
        final dayIndex = (_day - 1).clamp(0, _dayCount - 1);
        if (_dayController.selectedItem != dayIndex) {
          _dayController.jumpToItem(dayIndex);
        }
      }
    });
  }

  String _monthLabel(LunarMonth m) {
    final month = m.getMonth().abs();
    final isLeap = m.isLeap();
    if (DateFormatUtil.isEnglish) {
      return DateFormatUtil.pickerLunarMonthLabel(
        month: month,
        isLeapMonth: isLeap,
      );
    }
    final leap = isLeap ? '闰' : '';
    return '$leap${LunarCalendarUtil.monthLabel(
      year: m.getYear(),
      month: month,
      isLeapMonth: isLeap,
    )}月';
  }

  Widget _pickerLabel(String text, {double horizontal = 10}) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: Text(
            text,
            style: AppFonts.pickerItem,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  String _dayLabel(int day) {
    if (DateFormatUtil.isEnglish) {
      return DateFormatUtil.pickerDayLabel(day);
    }
    return _dayLabels[day - 1];
  }

  void _applyMonthSelection(int index) {
    _monthIndex = index;
    _clampDay();
    _resetDayControllerIfNeeded();
  }

  void _applyYearSelection(int index) {
    final prevMonth = _selectedMonth.getMonth().abs();
    final prevLeap = _selectedMonth.isLeap();
    _year = _years[index];
    _loadMonths();
    _monthIndex = _indexForMonth(prevMonth, prevLeap);
    _clampDay();
    _resetDayControllerIfNeeded();
  }

  void _onYearChanged(int index) {
    if (!_ready || index < 0 || index >= _years.length) return;
    if (_years[index] == _year) return;
    _applyYearSelection(index);
    setState(() {});
    _syncPickerPositions();
  }

  void _onMonthChanged(int index) {
    if (!_ready || index < 0 || index >= _months.length) return;
    if (index == _monthIndex) return;
    _applyMonthSelection(index);
    setState(() {});
    _syncPickerPositions();
  }

  void _onDayChanged(int index) {
    if (!_ready) return;
    final day = index + 1;
    if (day > _dayCount || day < 1 || day == _day) return;
    setState(() => _day = day);
  }

  void _confirm() {
    final m = _selectedMonth;
    Navigator.of(context).pop(
      LunarDateSelection(
        year: m.getYear(),
        month: m.getMonth().abs(),
        day: _day,
        isLeapMonth: m.isLeap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayCount = _dayCount;

    return AlertDialog(
      title: Text(
        tr('dialogs.lunar_picker_title'),
        style: AppFonts.dialogTitle,
      ),
      content: SizedBox(
        height: 180,
        width: double.maxFinite,
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: CupertinoPicker(
                scrollController: _yearController,
                itemExtent: 36,
                onSelectedItemChanged: _onYearChanged,
                children: [
                  for (final y in _years)
                    _pickerLabel(DateFormatUtil.pickerYearLabel(y)),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: CupertinoPicker(
                scrollController: _monthController,
                itemExtent: 36,
                onSelectedItemChanged: _onMonthChanged,
                children: [
                  for (final m in _months)
                    _pickerLabel(_monthLabel(m), horizontal: 4),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: CupertinoPicker(
                key: ValueKey(_lastDayCount),
                scrollController: _dayController,
                itemExtent: 36,
                onSelectedItemChanged: _onDayChanged,
                children: [
                  for (var d = 1; d <= dayCount; d++)
                    _pickerLabel(_dayLabel(d)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('common.cancel')),
        ),
        TextButton(
          onPressed: _confirm,
          child: Text(
            tr('common.confirm'),
            style: AppFonts.dialogAction.copyWith(color: AppColors.accentDark),
          ),
        ),
      ],
    );
  }
}
