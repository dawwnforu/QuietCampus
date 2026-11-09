import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/main.dart';
import 'package:quiet_campus/app.dart';
import 'package:flutter_quill/flutter_quill.dart';

void main() {
  testWidgets(
    'unconfigured app explains setup without exposing a secret field',
    (tester) async {
      await tester.pumpWidget(
        const SetupApp(message: '请先连接自己的同步服务', detail: '服务配置说明'),
      );
      expect(find.text('请先连接自己的同步服务'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets('Chinese rich text survives serialization and narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: ReadOnlyDocument(
            delta: const [
              {
                'insert': '今天参加了志愿活动',
                'attributes': {'bold': true},
              },
              {'insert': '\n'},
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('今天参加了志愿活动', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
