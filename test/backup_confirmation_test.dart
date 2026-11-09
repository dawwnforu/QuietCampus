import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/ui_helpers.dart';

void main() {
  testWidgets(
    'download completion alone never confirms a backup; explicit confirmation can be revoked',
    (tester) async {
      final completer = Completer<void>();
      final confirmations = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackupDownloadConfirmation(
              download: () => completer.future,
              onConfirmed: confirmations.add,
            ),
          ),
        ),
      );
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      expect(confirmations, [false]);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      completer.complete();
      await tester.pumpAndSettle();
      expect(confirmations, [false]);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(confirmations, [false, true]);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(confirmations, [false, true, false]);
    },
  );
  testWidgets('a failed backup export never unlocks replacement', (
    tester,
  ) async {
    final confirmations = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupDownloadConfirmation(
            download: () async => throw StateError('Test-only failure'),
            onConfirmed: confirmations.add,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(confirmations, [false]);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Test-only failure'), findsOneWidget);
  });
}
