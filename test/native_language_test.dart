import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiet_campus/auth_pages.dart';
import 'package:quiet_campus/controller.dart';
import 'package:quiet_campus/editor.dart';
import 'package:quiet_campus/main.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/passphrase_field.dart';
import 'package:quiet_campus/record_export.dart';
import 'package:quiet_campus/reminders.dart';
import 'package:quiet_campus/settings.dart';

class _Auth extends GoTrueClient {
  _Auth()
    : super(url: 'https://example.invalid/auth/v1', autoRefreshToken: false);
  bool signedIn = false;
  @override
  User? get currentUser => signedIn
      ? User(
          id: 'fictional-owner',
          email: 'student-test@example.invalid',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-11-02T00:00:00Z',
        )
      : null;
}

class _Client implements SupabaseClient {
  @override
  final _Auth auth = _Auth();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No network in fixture');
}

class _NoCrypto implements SodiumSumo {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No archive crypto in UI fixture');
}

class _Controller extends ArchiveController {
  _Controller(this.fixtureClient)
    : super(
        fixtureClient,
        _NoCrypto(),
        const FlutterSecureStorage(),
        Reminders(),
      );
  final _Client fixtureClient;
  bool setup = true;
  bool opened = false;
  @override
  bool get unlocked => opened;
  @override
  bool get needsSetup => setup;
  @override
  Future<void> openAccount() async {}
  @override
  Future<String> createVault(String password) async =>
      throw StateError('Offline fixture');
}

Finder passphraseField(String label) => find.descendant(
  of: find.widgetWithText(PassphraseField, label),
  matching: find.byType(TextField),
);

void main() {
  late _Client client;
  late _Controller controller;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    client = _Client();
    controller = _Controller(client);
  });
  tearDown(() {
    controller.dispose();
    client.auth.dispose();
  });

  testWidgets(
    'native sign-in switches and persists UI language without replacing email input; labels and tap targets remain accessible',
    (tester) async {
      await tester.pumpWidget(QuietCampusApp(controller: controller));
      await tester.pumpAndSettle();
      final originalState = tester.state(find.byType(LoginPage));
      await tester.enterText(
        find.byType(TextField),
        'keep-this@example.invalid',
      );
      await tester.tap(find.byKey(const Key('language-switch')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(LoginPage)), same(originalState));
      expect(find.text('Send code'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'keep-this@example.invalid',
      );
      expect(await controller.secure.read(key: 'quiet-campus.language'), 'en');
      expect(controller.entries, isEmpty);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semantics.dispose();
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native unlock keeps both passphrases and visibility while changing language; validation and failures follow locale',
    (tester) async {
      client.auth.signedIn = true;
      controller.accountReady = true;
      await tester.pumpWidget(QuietCampusApp(controller: controller));
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(UnlockPage));
      await tester.enterText(passphraseField('加密口令'), 'short');
      await tester.enterText(passphraseField('再次输入加密口令'), 'short');
      await tester.tap(find.byTooltip('显示加密口令'));
      await tester.tap(find.byKey(const Key('language-switch')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(UnlockPage)), same(state));
      expect(
        tester
            .widget<TextField>(passphraseField('Encryption passphrase'))
            .controller!
            .text,
        'short',
      );
      expect(
        tester
            .widget<TextField>(passphraseField('Encryption passphrase'))
            .obscureText,
        false,
      );
      expect(
        tester
            .widget<TextField>(passphraseField('Confirm passphrase'))
            .obscureText,
        true,
      );
      await tester.ensureVisible(find.text('Create archive'));
      await tester.tap(find.text('Create archive'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 12 characters'), findsWidgets);
      await tester.enterText(
        passphraseField('Encryption passphrase'),
        'a long fixture passphrase',
      );
      await tester.enterText(
        passphraseField('Confirm passphrase'),
        'a long fixture passphrase',
      );
      await tester.ensureVisible(find.text('Create archive'));
      await tester.tap(find.text('Create archive'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Creation did not finish.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(passphraseField('Encryption passphrase'))
            .controller!
            .text,
        'a long fixture passphrase',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'native home shows the correct edition and sync text; language changes preserve original records, rich text, tags and editor drafts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      client.auth.signedIn = true;
      controller.accountReady = true;
      controller.opened = true;
      controller.syncStatus = '有 2 项版本冲突';
      controller.entries = [
        Entry(
          id: 'fictional',
          title: '保存',
          tags: const ['项目'],
          delta: const [
            {
              'insert': '中文原文 Save {count}\n',
              'attributes': {'bold': true},
            },
          ],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
      final original = recordsJson(controller.entries);
      await tester.pumpWidget(QuietCampusApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-switch')));
      await tester.pumpAndSettle();
      const production =
          String.fromEnvironment('APP_ENVIRONMENT') == 'production';
      expect(
        find.text(production ? 'Cloud sync edition' : 'Cloud sync test edition'),
        findsOneWidget,
      );
      expect(
        find.text(production ? 'Cloud sync test edition' : 'Cloud sync edition'),
        findsNothing,
      );
      expect(find.text('Local browser edition'), findsNothing);
      expect(find.text('2 version conflicts'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(find.byTooltip('New record'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Write a journal'));
      await tester.pumpAndSettle();
      final state = tester.state<EntryEditorState>(find.byType(EntryEditor));
      state.title.text = '保存 Save {count}';
      state.quill.document.insert(0, '原文 不翻译\n');
      state.tags.text = '#待完成';
      final delta = jsonEncode(state.quill.document.toDelta().toJson());
      await tester.tap(find.byKey(const Key('language-switch')));
      await tester.pumpAndSettle();
      expect(
        tester.state<EntryEditorState>(find.byType(EntryEditor)),
        same(state),
      );
      expect(state.title.text, '保存 Save {count}');
      expect(state.tags.text, '#待完成');
      expect(jsonEncode(state.quill.document.toDelta().toJson()), delta);
      expect(recordsJson(controller.entries), original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'saved English preference applies to settings and passphrase dialogs at large text size without clearing fields',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'quiet-campus.language': 'en',
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      client.auth.signedIn = true;
      controller.accountReady = true;
      await tester.pumpWidget(QuietCampusApp(controller: controller));
      await tester.pumpAndSettle();
      expect(find.text('Create your private archive'), findsOneWidget);
      final context = tester.element(find.byType(UnlockPage));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsPage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My settings'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Export encrypted backup'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Export encrypted backup'), findsOneWidget);
      final dialog = ChangePassphraseDialog(
        onUpdate: (_) async => throw StateError('Offline fixture'),
      );
      showDialog<void>(
        context: tester.element(find.byType(SettingsPage)),
        builder: (_) => dialog,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        passphraseField('New passphrase'),
        'kept fixture phrase',
      );
      await tester.enterText(
        passphraseField('Confirm new passphrase'),
        'kept fixture phrase',
      );
      await tester.ensureVisible(find.text('Update'));
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Update did not finish.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(passphraseField('New passphrase'))
            .controller!
            .text,
        'kept fixture phrase',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
