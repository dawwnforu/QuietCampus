import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'model.dart';

class Reminders {
  final plugin = FlutterLocalNotificationsPlugin();
  String warning = '';
  String _scheduled = '';
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: '静档',
          appUserModelId: 'cn.quietcampus.quiet_campus',
          guid: '7359510e-e0be-4f47-91fd-1a427df2da43',
        ),
      ),
    );
  }

  Future<bool> requestPermission() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  Future<bool> requestExactPermission() async {
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    final allowed = await android.requestExactAlarmsPermission() ?? false;
    _scheduled = '';
    return allowed;
  }

  Future<void> reconcile(List<Entry> entries, {required bool enabled}) async {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    final upcoming = enabled
        ? entries
              .where(
                (e) =>
                    e.reminder?.isAfter(DateTime.now()) == true &&
                    (e.kind != 'activity' || e.reminderTarget == 'app') &&
                    e.status != ActivityStatus.cancelled &&
                    e.status != ActivityStatus.completed,
              )
              .toList()
        : <Entry>[];
    upcoming.sort((a, b) => a.reminder!.compareTo(b.reminder!));
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final precise =
        android == null ||
        await android.canScheduleExactNotifications() == true;
    final key =
        '${zone.identifier}:$precise:${upcoming.take(60).map((e) => '${e.id}:${e.reminder!.toIso8601String()}').join('|')}';
    warning = [
      if (upcoming.length > 60) '系统已安排最近 60 项提醒，打开应用会继续安排后续提醒。',
      if (!precise && upcoming.isNotEmpty) '当前为普通提醒，系统可能延迟；可在设置中授权安卓精确提醒。',
    ].join('\n');
    if (key == _scheduled) return;
    await plugin.cancelAll();
    var id = 0;
    for (final entry in upcoming.take(60)) {
      await plugin.zonedSchedule(
        id: ++id,
        title: '你有一项待办提醒',
        body: '打开静档，查看自己的安排。',
        scheduledDate: tz.TZDateTime.from(entry.reminder!, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'private-reminders',
            '个人待办',
            channelDescription: '你主动设置的活动与记录提醒',
            visibility: NotificationVisibility.private,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
        androidScheduleMode: precise
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    _scheduled = key;
  }
}
