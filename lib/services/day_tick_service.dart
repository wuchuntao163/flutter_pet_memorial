import 'dart:async';

import 'package:flutter/widgets.dart';

import 'widget_service.dart';

/// 日历日变化时通知 UI 刷新（首页倒计时、已陪伴天数等依赖 DateTime.now() 的展示）
class DayTickService extends ChangeNotifier with WidgetsBindingObserver {
  DayTickService._();

  static final DayTickService instance = DayTickService._();

  Timer? _midnightTimer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextMidnight();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _midnightTimer = null;
  }

  void _scheduleNextMidnight() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _midnightTimer = Timer(delay, _onCalendarDayChanged);
  }

  void _onCalendarDayChanged() {
    notifyListeners();
    _scheduleNextMidnight();
    // 同步桌面小组件倒计时数据（App 在前台时）
    unawaited(WidgetService.instance.updateWidget());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      notifyListeners();
      _scheduleNextMidnight();
      unawaited(WidgetService.instance.updateWidget());
    }
  }
}
