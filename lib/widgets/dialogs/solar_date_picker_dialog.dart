import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../config/colors.dart';
import '../../config/fonts.dart';
import '../../l10n/tr.dart';
import '../../utils/date_format_util.dart';

Future<DateTime?> showSolarDatePickerDialog(
  BuildContext context, {
  DateTime? initial,
}) {
  final now = DateTime.now();
  initial ??= DateTime(now.year, now.month, now.day);

  return showDialog<DateTime>(
    context: context,
    builder: (context) => _SolarDatePickerDialog(initial: initial!),
  );
}

class _SolarDatePickerDialog extends StatefulWidget {
  final DateTime initial;

  const _SolarDatePickerDialog({required this.initial});

  @override
  State<_SolarDatePickerDialog> createState() => _SolarDatePickerDialogState();
}

class _SolarDatePickerDialogState extends State<_SolarDatePickerDialog> {
  static final _years = [for (var y = 1970; y <= 2100; y++) y];
  static final _months = [for (var m = 1; m <= 12; m++) m];

  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  late int _year;
  late int _month;
  late int _day;
  int _lastDayCount = 0;

  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
    _day = widget.initial.day;
    _clampDay();
    _lastDayCount = _dayCount;
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_year).clamp(0, _years.length - 1),
    );
    _monthController = FixedExtentScrollController(
      initialItem: (_month - 1).clamp(0, _months.length - 1),
    );
    _dayController = FixedExtentScrollController(
      initialItem: (_day - 1).clamp(0, _dayCount - 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ready = true;
    });
  }

  int get _dayCount => DateTime(_year, _month + 1, 0).day;

  void _clampDay() {
    final maxDay = _dayCount;
    if (_day > maxDay) _day = maxDay;
    if (_day < 1) _day = 1;
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
          _monthController.selectedItem != _month - 1) {
        _monthController.jumpToItem(_month - 1);
      }
      if (_dayController.hasClients) {
        final dayIndex = (_day - 1).clamp(0, _dayCount - 1);
        if (_dayController.selectedItem != dayIndex) {
          _dayController.jumpToItem(dayIndex);
        }
      }
    });
  }

  void _applyYearSelection(int index) {
    _year = _years[index];
    _clampDay();
    _resetDayControllerIfNeeded();
  }

  void _applyMonthSelection(int index) {
    _month = _months[index];
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
    if (_months[index] == _month) return;
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
    Navigator.of(context).pop(DateTime(_year, _month, _day));
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

  @override
  Widget build(BuildContext context) {
    final dayCount = _dayCount;

    return AlertDialog(
      title: Text(
        tr('dialogs.solar_picker_title'),
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
                    _pickerLabel(
                      DateFormatUtil.pickerSolarMonthLabel(m),
                      horizontal: 4,
                    ),
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
                    _pickerLabel(DateFormatUtil.pickerDayLabel(d)),
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
