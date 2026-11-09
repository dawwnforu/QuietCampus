import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:quiet_campus/backup_archive.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/vault_crypto.dart';

void main() {
  late SodiumSumo sodium;
  late VaultCrypto source;
  late String recovery;
  late Map<String, dynamic> snapshot;
  const password = 'Only fictional backup test 记录';
  const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const fileId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  Uint8List encode(Map<String, dynamic> value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));
  Map<String, dynamic> copy() =>
      jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>;

  setUpAll(() async {
    sodium = await SodiumSumoInit.init();
    final created = await VaultCrypto.create(sodium, owner, password);
    source = created.vault;
    recovery = created.recovery;
    final entry = Entry(
      id: 'legacy-record-1',
      title: '虚构的奖项 / A&B',
      delta: const [
        {
          'insert': '中文 <测试> Ａa😀\n',
          'attributes': {'bold': true},
        },
      ],
      tags: const ['成长'],
      attachments: const [Attachment(id: fileId, name: '虚构证明.png', size: 4)],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final material = Entry(
      id: 'material-1',
      title: '虚构材料',
      kind: 'material',
      delta: const [
        {'insert': '\n'},
      ],
      attachments: entry.attachments,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    snapshot = {
      'format': 'quiet-campus-backup',
      'v': 1,
      'owner': owner,
      'vault': {'owner_id': owner, 'revision': 1, 'envelope': created.header},
      'records': [
        SealedRecord(
          id: entry.id,
          revision: 0,
          ciphertext: source.sealJson(entry.id, entry.toJson()),
          deleted: false,
          dirty: true,
          generation: 2,
          mutationId: 'fixture-mutation',
        ).toJson(),
        SealedRecord(
          id: material.id,
          revision: 1,
          ciphertext: source.sealJson(material.id, material.toJson()),
          deleted: false,
        ).toJson(),
        SealedRecord(
          id: 'deleted-record',
          revision: 2,
          ciphertext: source.sealJson('deleted-record', {
            'v': 1,
            'deleted': true,
          }),
          deleted: true,
        ).toJson(),
      ],
      'conflicts': {
        'legacy-record-1': SealedRecord(
          id: entry.id,
          revision: 2,
          ciphertext: source.sealJson(entry.id, {
            ...entry.toJson(),
            'title': '远端虚构版本',
          }),
          deleted: false,
        ).toJson(),
      },
      'attachments': {
        fileId: base64Encode(
          source.sealAttachment(fileId, Uint8List.fromList([1, 2, 3, 4])),
        ),
      },
    };
  });
  tearDownAll(() => source.dispose());

  test('v1/v2 original backups, rich text, attachments and pending/conflict metadata round trip', () async {
    final archive = BackupArchive.decode(encode(snapshot));
    final opened = await archive.unlock(sodium, password);
    try {
      expect(opened.entries.map((e) => e.kind), ['note', 'material']);
      expect(opened.entries.first.title, '虚构的奖项 / A&B');
      expect(opened.entries.first.delta.first['attributes'], {'bold': true});
      expect(opened.conflicts['legacy-record-1']!.title, '远端虚构版本');
      expect(archive.records.first.dirty, true);
      expect(archive.records.first.generation, 2);
      expect(archive.records.first.mutationId, 'fixture-mutation');
      expect(BackupArchive.decode(encode(archive.toJson())).records.length, 3);
      expect(utf8.decode(encode(archive.toJson())), isNot(contains('虚构的奖项')));
      expect(
        utf8.decode(encode(archive.toJson())),
        isNot(contains('虚构证明.png')),
      );
    } finally {
      opened.dispose();
    }
  });

  test(
    'recovery key works; wrong passphrase and mismatched owner are rejected',
    () async {
      final archive = BackupArchive.decode(encode(snapshot));
      final opened = await archive.unlock(sodium, recovery, recovery: true);
      opened.dispose();
      await expectLater(
        archive.unlock(sodium, 'wrong fixture password'),
        throwsA(anything),
      );
      final changed = copy()..['owner'] = 'different-owner';
      expect(
        () => BackupArchive.decode(encode(changed)),
        throwsFormatException,
      );
      (changed['vault'] as Map)['owner_id'] = 'different-owner';
      await expectLater(
        BackupArchive.decode(encode(changed)).unlock(sodium, password),
        throwsA(anything),
      );
    },
  );

  test('record and attachment tampering are rejected before a restore is available', () async {
    for (final change in [false, true]) {
      final data = copy();
      if (change) {
        final frame = base64Decode(
          (data['attachments'] as Map)[fileId] as String,
        );
        frame[30] ^= 1;
        (data['attachments'] as Map)[fileId] = base64Encode(frame);
      } else {
        final box =
            ((data['records'] as List).first as Map)['ciphertext'] as Map;
        final bytes = base64Decode(box['box'] as String)..[0] ^= 1;
        box['box'] = base64Encode(bytes);
      }
      await expectLater(
        BackupArchive.decode(encode(data)).unlock(sodium, password),
        throwsA(anything),
      );
    }
  });

  test('missing attachment and mismatched declared length reject the whole archive', () async {
    final absent = copy()..['attachments'] = <String, dynamic>{};
    await expectLater(
      BackupArchive.decode(encode(absent)).unlock(sodium, password),
      throwsFormatException,
    );
    final changed = copy();
    final first = (changed['records'] as List).first as Map;
    final plain = source.openJson(
      first['id'] as String,
      Map<String, dynamic>.from(first['ciphertext'] as Map),
    );
    ((plain['attachments'] as List).first as Map)['size'] = 5;
    first['ciphertext'] = source.sealJson(first['id'] as String, plain);
    await expectLater(
      BackupArchive.decode(encode(changed)).unlock(sodium, password),
      throwsFormatException,
    );
  });

  test('unknown schema, unsupported KDF, duplicates, orphan conflicts and malformed bytes reject', () {
    final cases = <Map<String, dynamic>>[];
    cases.add(copy()..['v'] = 2);
    final kdf = copy();
    ((kdf['vault'] as Map)['envelope'] as Map)['mem'] = 1024;
    cases.add(kdf);
    final duplicate = copy();
    (duplicate['records'] as List).add((duplicate['records'] as List).first);
    cases.add(duplicate);
    final orphan = copy()..['records'] = [];
    cases.add(orphan);
    for (final value in cases) {
      expect(() => BackupArchive.decode(encode(value)), throwsFormatException);
    }
    expect(
      () => BackupArchive.decode(Uint8List.fromList([255])),
      throwsFormatException,
    );
    expect(
      () => BackupArchive.decode(Uint8List(BackupArchive.maxBytes + 1)),
      throwsFormatException,
    );
  });

  test(
    'unreadable rich text and future content version reject before import',
    () async {
      for (final future in [false, true]) {
        final changed = copy();
        final first = (changed['records'] as List).first as Map;
        final plain = source.openJson(
          first['id'] as String,
          Map<String, dynamic>.from(first['ciphertext'] as Map),
        );
        if (future) {
          plain['v'] = 3;
        } else {
          plain['delta'] = [
            {
              'insert': {'unknown-block': true},
            },
          ];
        }
        first['ciphertext'] = source.sealJson(first['id'] as String, plain);
        await expectLater(
          BackupArchive.decode(encode(changed)).unlock(sodium, password),
          throwsA(anything),
        );
      }
    },
  );
}
