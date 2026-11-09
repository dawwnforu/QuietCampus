import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiet_campus/demo.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/editor.dart';

void main() {
  testWidgets('all three record choices save, reopen and retain their kind', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = DemoController();
    await tester.pumpWidget(ArchiveDemo(controller: controller));
    await tester.pumpAndSettle();
    for (final option in [
      ('写日记', 'note'),
      ('留经历', 'experience'),
      ('存项目', 'project'),
    ]) {
      await tester.tap(find.byTooltip('新记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(option.$1));
      await tester.pumpAndSettle();
      final title = '测试${option.$1}';
      await tester.enterText(find.byType(TextField).first, title);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      final saved = controller.entries.first;
      expect(saved.kind, option.$2);
      expect(Entry.fromJson(saved.id, saved.toJson()).kind, option.$2);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EntryEditor>(find.byType(EntryEditor)).entry!.kind,
        option.$2,
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(controller.entries.first.kind, option.$2);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
