import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/tr.dart';
import '../models/memorial_day.dart';
import '../utils/memorial_reminder_schedule.dart';

/// 纪念日本地通知
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const _channelId = 'memorial_reminders';

  NotificationDetails get _notificationDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      tr('reminder.channel_name'),
      channelDescription: tr('reminder.channel_desc'),
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReminderService] timezone fallback: $e');
      }
      tz.setLocalLocation(tz.local);
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        tr('reminder.channel_name'),
        description: tr('reminder.channel_desc'),
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<void> requestPermission() async {
    await init();

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// 仅为列表中的纪念日注册/更新提醒，不取消其他已存在的通知
  Future<void> syncMemorials(List<MemorialDay> days) async {
    await init();
    for (final day in days) {
      await syncMemorial(day);
    }
  }

  /// 同步单条纪念日提醒：关闭提醒或更新后先取消再按需重新注册
  Future<void> syncMemorial(MemorialDay day) async {
    await init();
    await cancelMemorial(day.id);
    if (day.hasReminder) {
      await _schedule(day);
    }
  }

  Future<void> cancelMemorial(String memorialId) async {
    await init();
    await _plugin.cancel(_notificationId(memorialId));
  }

  Future<void> _schedule(MemorialDay day) async {
    final next = MemorialReminderSchedule.nextTrigger(day);
    if (next == null) return;

    await _plugin.zonedSchedule(
      _notificationId(day.id),
      day.title,
      _bodyFor(day),
      tz.TZDateTime.from(next, tz.local),
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: MemorialReminderSchedule.matchComponents(day),
      payload: day.id,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static int _notificationId(String memorialId) =>
      memorialId.hashCode & 0x7FFFFFFF;

  static String _bodyFor(MemorialDay day) {
    if (day.type == MemorialType.birthday) {
      return '${tr('reminder.birthday_prefix')}${day.title}'
          '${tr('reminder.birthday_suffix')}';
    }
    return '${tr('reminder.default_prefix')}${day.title}'
        '${tr('reminder.default_suffix')}';
  }
}
