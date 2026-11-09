import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiet_campus/controller.dart';
import 'package:quiet_campus/local_store.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/reminders.dart';
import 'package:quiet_campus/vault_crypto.dart';

class _NoNetwork implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No network in fixture');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('denying notifications still allows encrypted local writing and keeps the pending record', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Asia/Shanghai',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        calls.add(call.method);
        return call.method == 'requestNotificationsPermission' ? false : true;
      },
    );
    final store = LocalStore(':memory:');
    final sodium = await SodiumSumoInit.init();
    final created = await VaultCrypto.create(
      sodium,
      'fictional-owner',
      'Fictional reminders only 2026',
    );
    final controller =
        ArchiveController(
            _NoNetwork(),
            sodium,
            const FlutterSecureStorage(),
            Reminders(),
          )
          ..store = store
          ..vault = created.vault;
    try {
      await controller.reminders.initialize();
      expect(await controller.enableNotifications(true), isFalse);
      expect(controller.notificationsEnabled, isFalse);
      final now = DateTime.now();
      final entry = Entry(
        id: 'fictional-note',
        title: '拒绝提醒仍能记录',
        delta: const [
          {'insert': '虚构自由记录\n'},
        ],
        createdAt: now,
        updatedAt: now,
        reminder: now.add(const Duration(days: 1)),
      );
      await controller.save(entry, baseRevision: 0);
      expect(controller.entry(entry.id)!.plainText, entry.plainText);
      expect(store.pending, hasLength(1));
      final ciphertext = store.pending.single.ciphertext;
      expect(jsonEncode(ciphertext), isNot(contains(entry.title)));
      expect(jsonEncode(ciphertext), isNot(contains(entry.plainText.trim())));
      expect(
        created.vault.openJson(entry.id, ciphertext)['title'],
        entry.title,
      );
      expect(
        calls.where((call) => call == 'requestNotificationsPermission'),
        hasLength(1),
      );
      expect(calls, isNot(contains('zonedSchedule')));
    } finally {
      controller.dispose();
      created.vault.dispose();
      store.close();
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    }
  });
  test('app alarms fall back without exact permission and never include system calendar entries or private text', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    var precise = false;
    final scheduled = <Map<dynamic, dynamic>>[];
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'Asia/Shanghai',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        if (call.method == 'canScheduleExactNotifications') return precise;
        if (call.method == 'zonedSchedule') {
          scheduled.add(call.arguments as Map);
        }
        return true;
      },
    );
    try {
      final service = Reminders();
      await service.initialize();
      final later = DateTime.now().add(const Duration(days: 1));
      final entries = [
        for (final target in ['app', 'system'])
          Entry(
            id: target,
            kind: 'activity',
            title: '私人活动',
            delta: const [
              {'insert': '绝不进入通知的正文\n'},
            ],
            createdAt: later,
            updatedAt: later,
            reminder: later,
            reminderTarget: target,
          ),
      ];
      await service.reconcile(entries, enabled: true);
      expect(scheduled.length, 1);
      expect(
        (scheduled.single['platformSpecifics'] as Map)['scheduleMode'],
        'inexactAllowWhileIdle',
      );
      expect(scheduled.single['title'], '你有一项待办提醒');
      expect(scheduled.single.toString(), isNot(contains('私人活动')));
      expect(service.warning, contains('普通提醒'));
      precise = true;
      await service.reconcile(entries, enabled: true);
      expect(
        (scheduled.last['platformSpecifics'] as Map)['scheduleMode'],
        'exactAllowWhileIdle',
      );
      expect(service.warning, isEmpty);
      await service.reconcile(entries, enabled: false);
      expect(scheduled.length, 2);
    } finally {
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
