// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';
import 'package:quiet_campus/vault_crypto.dart';
import 'package:quiet_campus/model.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> rejects(Future<void> Function() action, String message) async {
  var rejected = false;
  try {
    await action();
  } catch (_) {
    rejected = true;
  }
  check(rejected, message);
}

Future<void> main() async {
  final sodium = await SodiumSumoInit.init();
  const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const password = 'Only my own private passphrase 记录';
  final created = await VaultCrypto.create(sodium, owner, password);
  final vault = created.vault;
  final secondDevice = await VaultCrypto.unlock(
    sodium,
    owner,
    created.header,
    password,
  );
  final recovered = await VaultCrypto.unlock(
    sodium,
    owner,
    created.header,
    created.recovery,
    recovery: true,
  );
  try {
    final entry = Entry(
      id: 'record-1',
      title: '第一次志愿服务',
      delta: [
        {'insert': '有点紧张，也很开心。\n'},
      ],
      tags: ['志愿', '大学生活'],
      attachments: const [Attachment(id: 'proof', name: '志愿证明.pdf', size: 12)],
      createdAt: DateTime.utc(2026, 10, 20),
      updatedAt: DateTime.utc(2026, 10, 20),
    );
    final material = Entry(
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      kind: 'material',
      title: '虚构的私密奖状',
      delta: const [
        {'insert': '仅供加密测试的材料说明\n'},
      ],
      materialCategory: '奖项',
      materialDate: DateTime(2026, 10, 20),
      attachments: const [
        Attachment(
          id: '11111111-1111-4111-8111-111111111111',
          name: '私密原件.pdf',
          size: 4,
        ),
      ],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final materialBox = vault.sealJson(material.id, material.toJson());
    for (final secretText in [
      material.title,
      material.materialCategory,
      material.plainText.trim(),
      material.attachments.single.name,
    ]) {
      check(
        !jsonEncode(materialBox).contains(secretText),
        'material metadata leaked',
      );
    }
    final materialRoundTrip = Entry.fromJson(
      material.id,
      secondDevice.openJson(material.id, materialBox),
    );
    check(
      materialRoundTrip.materialDate == material.materialDate &&
          materialRoundTrip.materialCategory == material.materialCategory &&
          materialRoundTrip.attachments.single.name ==
              material.attachments.single.name,
      'material metadata round trip failed',
    );
    final linked = Entry.fromJson(entry.id, {
      ...entry.toJson(),
      'v': 2,
      'attachments': [],
      'delta': withMaterialReference(entry.delta, material.id),
    });
    final linkedBox = vault.sealJson(linked.id, linked.toJson());
    check(
      Entry.fromJson(
        linked.id,
        recovered.openJson(linked.id, linkedBox),
      ).materialIds.contains(material.id),
      'material reference recovery failed',
    );
    final encrypted = vault.sealJson(entry.id, entry.toJson());
    check(!jsonEncode(encrypted).contains(entry.title), 'record title leaked');
    check(!jsonEncode(created.header).contains(password), 'password leaked');
    check(
      !jsonEncode(created.header).contains(created.recovery),
      'recovery key leaked',
    );
    final roundTrip = Entry.fromJson(
      entry.id,
      secondDevice.openJson(entry.id, encrypted),
    );
    check(
      roundTrip.title == entry.title && roundTrip.plainText == entry.plainText,
      'document round trip failed',
    );
    check(
      roundTrip.attachments.single.name == '志愿证明.pdf',
      'attachment metadata lost',
    );
    check(
      roundTrip.matches('志愿 开心') && !roundTrip.matches('不存在'),
      'Chinese search failed',
    );
    check(
      recovered.openJson(entry.id, encrypted)['title'] == entry.title,
      'recovery failed',
    );
    await rejects(() async {
      await VaultCrypto.unlock(
        sodium,
        owner,
        created.header,
        'a wrong but long password',
      );
    }, 'wrong password accepted');
    await rejects(() async {
      await VaultCrypto.unlock(
        sodium,
        'another-account',
        created.header,
        password,
      );
    }, 'vault transplanted across accounts');
    await rejects(() async {
      vault.openJson('record-2', encrypted);
    }, 'record ID not authenticated');
    final tampered = Map<String, dynamic>.from(encrypted);
    final box = base64Decode(tampered['box'] as String);
    box[0] ^= 1;
    tampered['box'] = base64Encode(box);
    await rejects(() async {
      vault.openJson(entry.id, tampered);
    }, 'ciphertext tampering accepted');
    final bytes = Uint8List.fromList([0, 255, 17, 99]);
    final file = vault.sealBytes('proof', bytes, attachment: true);
    check(
      base64Encode(secondDevice.openBytes('proof', file, attachment: true)) ==
          base64Encode(bytes),
      'attachment round trip failed',
    );
    await rejects(() async {
      vault.openBytes('proof', file);
    }, 'record/attachment domains are interchangeable');
    final frame = vault.sealAttachment('proof', bytes);
    check(
      frame.length == bytes.length + 41,
      'binary attachment framing changed',
    );
    check(
      base64Encode(secondDevice.openAttachment('proof', frame)) ==
          base64Encode(bytes),
      'binary attachment failed',
    );
    await rejects(() async {
      vault.openAttachment('other-proof', frame);
    }, 'attachment ID not authenticated');
    if (const bool.fromEnvironment('EMIT_CRYPTO_FIXTURE')) {
      const fid = '11111111-1111-4111-8111-111111111111';
      final value = {
        ...entry.toJson(),
        'attachments': [
          {'id': fid, 'name': '志愿证明.pdf', 'size': bytes.length},
        ],
      };
      final fixture = {
        'secret': password,
        'recovery': created.recovery,
        'backup': {
          'format': 'quiet-campus-backup',
          'v': 1,
          'owner': owner,
          'vault': {'envelope': created.header},
          'records': [
            {
              'id': entry.id,
              'deleted': false,
              'ciphertext': vault.sealJson(entry.id, value),
            },
            {'id': material.id, 'deleted': false, 'ciphertext': materialBox},
            {
              'id': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
              'deleted': false,
              'ciphertext': vault.sealJson(
                'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
                linked.toJson(),
              ),
            },
          ],
          'conflicts': {},
          'attachments': {fid: base64Encode(vault.sealAttachment(fid, bytes))},
        },
      };
      print('CRYPTO_FIXTURE:${jsonEncode(fixture)}');
    }
    final rotated = await vault.wrap('a new long independent passphrase');
    final reset = await VaultCrypto.unlock(
      sodium,
      owner,
      rotated.header,
      rotated.recovery,
      recovery: true,
    );
    try {
      check(
        reset.openJson(entry.id, encrypted)['title'] == entry.title,
        'password reset lost old data',
      );
    } finally {
      reset.dispose();
    }
    await rejects(() async {
      await VaultCrypto.unlock(sodium, owner, rotated.header, password);
    }, 'old password accepted after rotation');
    print(
      'PASS: multi-device, recovery, wrong password, tampering, account/record/attachment binding, password reset, Chinese search, material metadata and rich references',
    );
  } finally {
    vault.dispose();
    secondDevice.dispose();
    recovered.dispose();
  }
}
