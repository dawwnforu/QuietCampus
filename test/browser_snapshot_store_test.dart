@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:quiet_campus/browser_snapshot_store.dart';

void main() {
  late BrowserSnapshotStore first;
  late BrowserSnapshotStore second;
  late String name;
  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

  setUp(() async {
    name = 'quiet-campus-test-${DateTime.now().microsecondsSinceEpoch}';
    first = await BrowserSnapshotStore.open(name: name);
    second = await BrowserSnapshotStore.open(name: name);
  });
  tearDown(() {
    first.close();
    second.close();
  });

  test(
    'real IndexedDB persists across connections and normal reopen',
    () async {
      expect(await first.read(), isNull);
      expect(await first.commit(bytes('sealed fixture'), baseRevision: 0), 1);
      final read = (await second.read())!;
      expect(read.revision, 1);
      expect(utf8.decode(read.bytes), 'sealed fixture');
      first.close();
      first = await BrowserSnapshotStore.open(name: name);
      expect(utf8.decode((await first.read())!.bytes), 'sealed fixture');
    },
  );

  test(
    'stale tab cannot overwrite a newer commit; previous bytes survive failure',
    () async {
      await first.commit(bytes('first fixture'), baseRevision: 0);
      await second.commit(bytes('newer fixture'), baseRevision: 1);
      await expectLater(
        first.commit(bytes('stale fixture'), baseRevision: 1),
        throwsStateError,
      );
      expect((await first.read())!.revision, 2);
      expect(utf8.decode((await first.read())!.bytes), 'newer fixture');
    },
  );

  test(
    'concurrent first writes result in one complete snapshot, never mixed data',
    () async {
      var successes = 0;
      var rejected = 0;
      await Future.wait([
        for (final item in [(first, 'fixture a'), (second, 'fixture b')])
          item.$1
              .commit(bytes(item.$2), baseRevision: 0)
              .then<void>(
                (_) {
                  successes++;
                },
                onError: (Object _) {
                  rejected++;
                },
              ),
      ]);
      expect(successes, 1);
      expect(rejected, 1);
      final snapshot = (await first.read())!;
      expect(snapshot.revision, 1);
      expect(['fixture a', 'fixture b'], contains(utf8.decode(snapshot.bytes)));
    },
  );

  test('invalid write leaves existing snapshot untouched', () async {
    await first.commit(bytes('existing fixture'), baseRevision: 0);
    await expectLater(
      first.commit(bytes('invalid fixture'), baseRevision: -1),
      throwsFormatException,
    );
    expect(utf8.decode((await second.read())!.bytes), 'existing fixture');
  });
}
