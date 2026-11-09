import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quiet_campus/backup_archive.dart';
import 'package:quiet_campus/controller.dart';
import 'package:quiet_campus/local_store.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/native_backup_restore.dart';
import 'package:quiet_campus/passphrase_field.dart';
import 'package:quiet_campus/reminders.dart';
import 'package:quiet_campus/sync_engine.dart';
import 'package:quiet_campus/vault_crypto.dart';

class _NoNetwork implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No network in fixture');
}

class _Controller extends ArchiveController {
  _Controller(SodiumSumo sodium)
    : super(_NoNetwork(), sodium, const FlutterSecureStorage(), Reminders());
  @override
  String get email => 'fictional@example.invalid';
  void Function()? duringSync;
  @override
  Future<void> sync() async {
    duringSync?.call();
    await super.sync();
  }
}

class _DialogController extends _Controller {
  _DialogController(super.sodium, this.prepared);
  final OpenedBackup prepared;
  @override
  Future<OpenedBackup> verifyBackup(
    BackupArchive archive,
    String secret, {
    bool recovery = false,
  }) async {
    if (secret != 'correct fixture phrase') throw StateError('测试口令不符，输入已保留');
    return prepared;
  }
}

class _NewerRemote implements SyncRemote {
  _NewerRemote(this.rows);
  final List<SealedRecord> rows;
  final events = <String>[];
  @override
  Future<void> upload(String id, Uint8List ciphertext) async {
    expect(ciphertext.first, 1);
    events.add('attachment:$id');
  }

  @override
  Future<Map<String, dynamic>> write(SealedRecord record) async =>
      throw StateError('Unresolved restored conflicts must not be uploaded');
  @override
  Future<List<SealedRecord>> readAll() async {
    events.add('read');
    return rows;
  }
}

void main() {
  const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const fileId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const password = 'Fictional restore only 2026';
  late SodiumSumo sodium;
  late VaultCrypto source;
  late String recovery;
  late Map<String, dynamic> envelope;
  late Map<String, dynamic> snapshot;
  late Directory directory;
  late _Controller controller;

  BackupArchive archive([Map<String, dynamic>? data]) => BackupArchive.decode(
    Uint8List.fromList(utf8.encode(jsonEncode(data ?? snapshot))),
  );

  void attach(_Controller c) {
    c.owner = owner;
    c.accountReady = true;
    c.header = envelope;
    c.headerRevision = 1;
    c.store = LocalStore('${directory.path}/restore.sqlite');
    c.store!.setMeta('vault', jsonEncode(snapshot['vault']));
  }

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    final created = await VaultCrypto.create(sodium, owner, password);
    source = created.vault;
    recovery = created.recovery;
    envelope = created.header;
    final entry = Entry(
      id: 'note',
      title: '虚构恢复',
      delta: const [
        {
          'insert': '保留富文本\n',
          'attributes': {'bold': true},
        },
      ],
      tags: const ['虚构'],
      attachments: const [Attachment(id: fileId, name: '虚构音频.wav', size: 3)],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final row = SealedRecord(
      id: entry.id,
      revision: 4,
      ciphertext: source.sealJson(entry.id, entry.toJson()),
      deleted: false,
      dirty: true,
      generation: 7,
      mutationId: 'pending-mutation',
    );
    final conflict = SealedRecord(
      id: entry.id,
      revision: 5,
      ciphertext: source.sealJson(entry.id, {
        ...entry.toJson(),
        'title': '远端虚构版本',
      }),
      deleted: false,
    );
    snapshot = {
      'format': 'quiet-campus-backup',
      'v': 1,
      'owner': owner,
      'vault': {'owner_id': owner, 'revision': 1, 'envelope': envelope},
      'records': [
        row.toJson(),
        SealedRecord(
          id: 'deleted',
          revision: 2,
          ciphertext: source.sealJson('deleted', {'v': 1, 'deleted': true}),
          deleted: true,
        ).toJson(),
      ],
      'conflicts': {'note': conflict.toJson()},
      'attachments': {
        fileId: base64Encode(
          source.sealAttachment(fileId, Uint8List.fromList([1, 2, 3])),
        ),
      },
    };
  });
  tearDownAll(() => source.dispose());
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('quiet-native-restore-');
    controller = _Controller(sodium);
    attach(controller);
  });
  tearDown(() async {
    controller.store?.close();
    controller.dispose();
    await directory.delete(recursive: true);
  });

  test('backup stops if the archive locks while syncing', () async {
    controller.vault = await VaultCrypto.unlock(
      sodium,
      owner,
      envelope,
      password,
    );
    controller.duringSync = controller.lock;
    await expectLater(
      controller.backup(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          '档案已锁定或账号已切换',
        ),
      ),
    );
    expect(controller.store!.meta('vault'), jsonEncode(snapshot['vault']));
  });

  test('native restore persists encrypted rich text, tombstones, outbox, conflicts and files without unlocking or network', () async {
    final opened = await controller.verifyBackup(archive(), password);
    try {
      expect(controller.store!.hasArchiveData, false);
      await controller.restoreBackup(opened);
      expect(controller.unlocked, false);
      expect(controller.entries, isEmpty);
      expect(controller.engine, isNull);
      controller.store!.close();
      controller.store = LocalStore('${directory.path}/restore.sqlite');
      final store = controller.store!;
      expect(store.get('note')!.generation, 7);
      expect(store.get('note')!.mutationId, 'pending-mutation');
      expect(store.get('note')!.dirty, true);
      expect(store.get('deleted')!.deleted, true);
      expect(store.conflicts['note']!.revision, 5);
      expect(
        store.pending,
        isEmpty,
      ); // Conflict stays pending for explicit resolution.
      expect(store.pendingAttachments.keys, [fileId]);
      final plaintext = source.openJson('note', store.get('note')!.ciphertext);
      expect(plaintext['delta'], [
        {
          'insert': '保留富文本\n',
          'attributes': {'bold': true},
        },
      ]);
      expect(source.openAttachment(fileId, store.attachment(fileId)!), [
        1,
        2,
        3,
      ]);
      expect(store.meta('vault'), jsonEncode(snapshot['vault']));
      expect(controller.canRestoreBackup, false);
      await expectLater(controller.restoreBackup(opened), throwsStateError);
      expect(store.records.length, 2);
    } finally {
      opened.dispose();
    }
  });

  test('wrong secret, account and changed envelope leave an empty database untouched; recovery key works', () async {
    await expectLater(
      controller.verifyBackup(archive(), 'wrong'),
      throwsA(anything),
    );
    controller.owner = 'another-account';
    await expectLater(
      controller.verifyBackup(archive(), password),
      throwsStateError,
    );
    controller.owner = owner;
    controller.header = {...envelope, 'salt': 'changed-envelope'};
    await expectLater(
      controller.verifyBackup(archive(), password),
      throwsStateError,
    );
    controller.header = Map.fromEntries(envelope.entries.toList().reversed);
    final opened = await controller.verifyBackup(
      archive(),
      recovery,
      recovery: true,
    );
    opened.dispose();
    expect(controller.store!.hasArchiveData, false);
  });

  test('state changed after preview cannot replace records, drafts or a different account', () async {
    final opened = await controller.verifyBackup(archive(), password);
    try {
      controller.owner = 'another-account';
      await expectLater(controller.restoreBackup(opened), throwsStateError);
      controller.owner = owner;
      controller.store!.putAttachment('local-draft', Uint8List.fromList([8]));
      await expectLater(controller.restoreBackup(opened), throwsStateError);
      expect(controller.store!.records, isEmpty);
      expect(controller.store!.attachment('local-draft'), [8]);
      expect(controller.store!.attachment(fileId), isNull);
    } finally {
      opened.dispose();
    }
  });

  test('SQLite failure after records/conflicts insertion rolls everything back; original metadata survives and retry works', () async {
    final opened = await controller.verifyBackup(archive(), password);
    try {
      controller.store!.db.execute(
        "CREATE TRIGGER interrupted_restore BEFORE INSERT ON attachments BEGIN SELECT RAISE(ABORT,'fixture interruption'); END",
      );
      await expectLater(controller.restoreBackup(opened), throwsA(anything));
      expect(controller.store!.hasArchiveData, false);
      expect(controller.store!.meta('vault'), jsonEncode(snapshot['vault']));
      controller.store!.db.execute('DROP TRIGGER interrupted_restore');
      await controller.restoreBackup(opened);
      expect(controller.store!.records.length, 2);
    } finally {
      opened.dispose();
    }
  });

  test('first reconciliation keeps a newer cloud deletion as an explicit conflict, not a resurrection', () async {
    final opened = await controller.verifyBackup(archive(), password);
    try {
      await controller.restoreBackup(opened);
      final remote = _NewerRemote([
        SealedRecord(
          id: 'note',
          revision: 6,
          ciphertext: source.sealJson('note', {'v': 1, 'deleted': true}),
          deleted: true,
        ),
      ]);
      await SyncEngine(controller.store!, remote).run();
      expect(remote.events, ['attachment:$fileId', 'read']);
      expect(controller.store!.get('note')!.deleted, false);
      expect(controller.store!.conflicts['note']!.deleted, true);
      expect(controller.store!.conflicts['note']!.revision, 6);
      expect(controller.store!.pending, isEmpty);
    } finally {
      opened.dispose();
    }
  });

  testWidgets(
    'English large-text narrow-screen preview cancels without touching the archive',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final prepared = await tester.runAsync(
        () => archive().unlock(sodium, password),
      );
      controller.store!.close();
      controller.dispose();
      controller = _DialogController(sodium, prepared!);
      attach(controller);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NativeBackupRestoreDialog(
                    controller: controller,
                    archive: prepared.archive,
                  ),
                ),
                child: const Text('打开恢复'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开恢复'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final field = find.descendant(
        of: find.byType(PassphraseField),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'correct fixture phrase');
      await tester.ensureVisible(find.text('Validate and preview'));
      await tester.tap(find.text('Validate and preview'));
      await tester.pumpAndSettle();
      expect(find.text('Restore preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.store!.hasArchiveData, false);
      expect(controller.store!.meta('vault'), jsonEncode(snapshot['vault']));
      expect(controller.unlocked, false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'dialog retains a wrong secret, supports visibility, previews without writing and restores only after confirmation',
    (tester) async {
      final prepared = await tester.runAsync(
        () => archive().unlock(sodium, password),
      );
      controller.store!.close();
      controller.dispose();
      controller = _DialogController(sodium, prepared!);
      attach(controller);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => NativeBackupRestoreDialog(
                    controller: controller,
                    archive: prepared.archive,
                  ),
                ),
                child: const Text('打开恢复'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开恢复'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(PassphraseField),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'wrong');
      await tester.tap(find.text('验证并预览'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'wrong');
      expect(controller.store!.hasArchiveData, false);
      await tester.tap(find.byTooltip('显示此备份的加密口令'));
      await tester.pump();
      expect(tester.widget<TextField>(field).obscureText, false);
      await tester.enterText(field, 'correct fixture phrase');
      await tester.tap(find.text('验证并预览'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 个对象'), findsOneWidget);
      expect(controller.store!.hasArchiveData, false);
      await tester.tap(find.text('确认恢复到本机空档案'));
      await tester.pumpAndSettle();
      expect(controller.store!.records.length, 2);
      expect(controller.unlocked, false);
      expect(find.text('恢复预览'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
