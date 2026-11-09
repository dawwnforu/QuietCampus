import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiet_campus/auth_pages.dart';
import 'package:quiet_campus/controller.dart';
import 'package:quiet_campus/local_store.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/passphrase_field.dart';
import 'package:quiet_campus/reminders.dart';
import 'package:quiet_campus/settings.dart';

class _UnusedCrypto implements SodiumSumo {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No crypto in UI fixture');
}

class _Auth extends GoTrueClient {
  _Auth()
    : super(url: 'https://example.invalid/auth/v1', autoRefreshToken: false);
  SignOutScope? signedOut;
  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.global}) async {
    signedOut = scope;
  }
}

class _Client implements SupabaseClient {
  @override
  final auth = _Auth();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No network in fixture');
}

class _Reminders extends Reminders {
  @override
  Future<void> reconcile(List<Entry> entries, {required bool enabled}) async {}
}

class _Controller extends ArchiveController {
  _Controller()
    : super(
        _Client(),
        _UnusedCrypto(),
        const FlutterSecureStorage(),
        _Reminders(),
      );
  bool setup = true;
  int attempts = 0;
  @override
  String get email => 'student-test@example.invalid';
  @override
  bool get needsSetup => setup;
  @override
  Future<String> createVault(String password) async {
    attempts++;
    throw StateError('Offline fixture');
  }

  @override
  Future<void> unlock(String secret, {bool recovery = false}) async {
    attempts++;
    throw StateError('Incorrect fixture secret');
  }
}

Finder field(String label) => find.descendant(
  of: find.widgetWithText(PassphraseField, label),
  matching: find.byType(TextField),
);

Future<void> screen(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'setup validates length and confirmation without clearing; both visibility controls work',
    (tester) async {
      final c = _Controller();
      await screen(tester, UnlockPage(controller: c));
      expect(find.text(c.email), findsOneWidget);
      await tester.enterText(field('加密口令'), 'short');
      await tester.enterText(field('再次输入加密口令'), 'short');
      await tester.ensureVisible(find.text('创建档案'));
      await tester.tap(find.text('创建档案'));
      await tester.pumpAndSettle();
      expect(c.attempts, 0);
      expect(find.text('加密口令至少需要 12 个字符'), findsOneWidget);
      expect(tester.widget<TextField>(field('加密口令')).controller!.text, 'short');
      await tester.enterText(field('加密口令'), 'a long test phrase');
      await tester.tap(find.text('创建档案'));
      await tester.pumpAndSettle();
      expect(find.text('两次加密口令不一致，请修改后重试'), findsOneWidget);
      expect(c.attempts, 0);
      await tester.ensureVisible(find.byTooltip('显示加密口令'));
      await tester.tap(find.byTooltip('显示加密口令'));
      await tester.pump();
      expect(tester.widget<TextField>(field('加密口令')).obscureText, false);
      expect(tester.widget<TextField>(field('再次输入加密口令')).obscureText, true);
      await tester.tap(find.byTooltip('显示再次输入加密口令'));
      await tester.pump();
      expect(tester.widget<TextField>(field('再次输入加密口令')).obscureText, false);
      await tester.enterText(field('再次输入加密口令'), 'a long test phrase');
      await tester.ensureVisible(find.text('创建档案'));
      await tester.tap(find.text('创建档案'));
      await tester.pumpAndSettle();
      expect(c.attempts, 1);
      expect(
        tester.widget<TextField>(field('加密口令')).controller!.text,
        'a long test phrase',
      );
      expect(
        tester.widget<TextField>(field('再次输入加密口令')).controller!.text,
        'a long test phrase',
      );
      expect(find.textContaining('创建未完成，输入已保留'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'wrong unlock retains input and recovery mode has a separate visibility state',
    (tester) async {
      final c = _Controller()..setup = false;
      await screen(tester, UnlockPage(controller: c));
      await tester.enterText(field('加密口令'), 'wrong secret');
      await tester.ensureVisible(find.text('解锁档案'));
      await tester.tap(find.text('解锁档案'));
      await tester.pumpAndSettle();
      expect(c.attempts, 1);
      expect(
        tester.widget<TextField>(field('加密口令')).controller!.text,
        'wrong secret',
      );
      expect(find.textContaining('无法解锁，输入已保留'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('显示加密口令'));
      await tester.tap(find.byTooltip('显示加密口令'));
      await tester.pump();
      await tester.tap(find.text('忘记口令？使用恢复密钥'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field('恢复密钥')).controller!.text, '');
      expect(tester.widget<TextField>(field('恢复密钥')).obscureText, true);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'reset keeps dialog and input on failure, retries and closes only on success',
    (tester) async {
      var calls = 0;
      var success = false;
      await screen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final key = await showDialog<String>(
                  context: context,
                  builder: (_) => ChangePassphraseDialog(
                    onUpdate: (secret) async {
                      calls++;
                      if (!success) throw StateError('Offline fixture');
                      return 'fixture recovery';
                    },
                  ),
                );
                if (context.mounted && key != null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('更新成功')));
                }
              },
              child: const Text('打开口令设置'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开口令设置'));
      await tester.pumpAndSettle();
      await tester.enterText(field('新加密口令'), 'short');
      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('加密口令至少需要 12 个字符'), findsOneWidget);
      await tester.enterText(field('新加密口令'), 'a long test phrase');
      await tester.enterText(field('再次输入新口令'), 'another long phrase');
      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('两次加密口令不一致，请修改后重试'), findsOneWidget);
      await tester.enterText(field('再次输入新口令'), 'a long test phrase');
      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(ChangePassphraseDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(field('新加密口令')).controller!.text,
        'a long test phrase',
      );
      expect(find.textContaining('更新未完成，输入已保留'), findsOneWidget);
      success = true;
      await tester.tap(find.text('更新'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(ChangePassphraseDialog), findsNothing);
      expect(find.text('更新成功'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account identity fits narrow screens, switching requires confirmation, cancel retains account',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = _Controller();
      await screen(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: AccountPanel(controller: c)),
        ),
      );
      expect(find.text('当前登录邮箱'), findsOneWidget);
      expect(find.text(c.email), findsOneWidget);
      await tester.tap(find.text('切换账号'));
      await tester.pumpAndSettle();
      expect(find.textContaining('本机密文、未同步修改和冲突版本会保留'), findsOneWidget);
      await tester.tap(find.text('留在当前账号'));
      await tester.pumpAndSettle();
      expect((c.client.auth as _Auth).signedOut, isNull);
      await tester.tap(find.text('切换账号'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '切换账号'));
      await tester.pumpAndSettle();
      expect((c.client.auth as _Auth).signedOut, SignOutScope.local);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  test('switch closes only the session and preserves ciphertext, outbox and conflicts for the original account', () async {
    final directory = Directory.systemTemp.createTempSync(
      'quiet-account-test-',
    );
    final path = '${directory.path}/account-a.sqlite';
    final c = _Controller();
    final store = LocalStore(path);
    c.owner = 'account-a';
    c.accountReady = true;
    c.header = {'fixture': 'sealed header'};
    c.store = store;
    store.setMeta('vault', 'sealed header');
    store.save('pending', {'box': 'ciphertext A'}, false, 'mutation');
    store.save('conflict', {'box': 'local ciphertext'}, false, 'mutation2');
    store.conflict(
      SealedRecord(
        id: 'conflict',
        revision: 1,
        ciphertext: {'box': 'remote ciphertext'},
        deleted: false,
      ),
    );
    try {
      await c.switchAccount();
      expect((c.client.auth as _Auth).signedOut, SignOutScope.local);
      expect(c.owner, isNull);
      expect(c.accountReady, false);
      expect(c.store, isNull);
      expect(c.entries, isEmpty);
      final reopened = LocalStore(path);
      try {
        expect(reopened.meta('vault'), 'sealed header');
        expect(reopened.pending.single.id, 'pending');
        expect(reopened.conflicts.keys, ['conflict']);
        expect(reopened.get('pending')!.ciphertext, {'box': 'ciphertext A'});
        final other = LocalStore('${directory.path}/account-b.sqlite');
        try {
          expect(other.records, isEmpty);
        } finally {
          other.close();
        }
      } finally {
        reopened.close();
      }
    } finally {
      c.dispose();
      directory.deleteSync(recursive: true);
    }
  });
}
