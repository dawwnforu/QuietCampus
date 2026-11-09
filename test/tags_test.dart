import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:quiet_campus/archive_actions.dart';
import 'package:quiet_campus/demo.dart';
import 'package:quiet_campus/demo_controller.dart';
import 'package:quiet_campus/editor.dart';
import 'package:quiet_campus/model.dart';
import 'package:quiet_campus/overview.dart';
import 'package:quiet_campus/tags.dart';
import 'package:quiet_campus/theme.dart';

Entry note(String id, List<String> tags) => Entry(
  id: id,
  title: '原始标题',
  delta: const [
    {'insert': '完整的正文\n'},
  ],
  tags: tags,
  createdAt: DateTime(2026, 10, 20),
  updatedAt: DateTime(2026, 10, 20),
);

class FailingTagsController extends DemoController {
  String? failOn;
  @override
  Future<void> save(Entry entry, {required int baseRevision}) async {
    if (entry.id == failOn) throw StateError('simulated local write failure');
    await super.save(entry, baseRevision: baseRevision);
  }
}

void main() {
  testWidgets(
    'tag usage opens all record kinds and searches partial keywords',
    (tester) async {
      tester.view.physicalSize = const Size(921, 871);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = DemoController()
        ..entries = [
          note('one', ['大学生活']),
          Entry.fromJson('project', {
            ...note('project', ['大学生活']).toJson(),
            'kind': 'project',
            'title': '课程整理',
            'delta': [
              {'insert': '完成课堂展示\n'},
            ],
            'role': '资料校对',
          }),
          Entry.fromJson('event', {
            ...note('event', ['大学生活']).toJson(),
            'kind': 'activity',
            'title': '图书馆活动',
          }),
          Entry.fromJson('outside', {
            ...note('outside', ['其他']).toJson(),
            'title': '不属于该标签的记录',
          }),
          Entry.fromJson(ArchiveActions.tagCatalogId, {
            ...note(ArchiveActions.tagCatalogId, ['大学生活', '未使用']).toJson(),
            'kind': 'tag_catalog',
          }),
        ];
      await tester.pumpWidget(ArchiveDemo(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('管理标签'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '#大学生活'));
      await tester.pumpAndSettle();
      expect(find.text('3 篇记录 · 已显示 3 篇'), findsOneWidget);
      expect(find.text('图书馆活动'), findsOneWidget);
      expect(find.text('课程整理'), findsOneWidget);
      expect(find.text('不属于该标签的记录'), findsNothing);
      final search = find.widgetWithText(TextField, '搜索标题、正文、标签、类型 · 支持模糊词');
      await tester.enterText(search, '课堂 展');
      await tester.pumpAndSettle();
      expect(find.text('1 篇记录 · 已显示 1 篇'), findsOneWidget);
      expect(find.text('课程整理'), findsOneWidget);
      expect(find.text('图书馆活动'), findsNothing);
      await tester.enterText(search, '校');
      await tester.pumpAndSettle();
      expect(find.text('课程整理'), findsOneWidget);
      await tester.tap(find.text('课程整理'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<QuillEditor>(find.byType(QuillEditor))
            .controller
            .document
            .toPlainText(),
        '完成课堂展示\n',
      );
      await tester.tap(find.byTooltip('编辑'));
      await tester.pumpAndSettle();
      expect(find.text('存项目'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.text('1 篇记录 · 已显示 1 篇'), findsOneWidget);
      await tester.enterText(search, '没有这个词');
      await tester.pumpAndSettle();
      expect(find.textContaining('没有找到匹配的记录'), findsOneWidget);
      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pumpAndSettle();
      expect(find.text('3 篇记录 · 已显示 3 篇'), findsOneWidget);
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '#未使用'));
      await tester.pumpAndSettle();
      expect(find.text('0 篇记录 · 已显示 0 篇'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
  testWidgets(
    'Chinese composition and hash shortcut preserve unfinished input',
    (tester) async {
      final input = TextEditingController();
      var selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: archiveTheme().copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TagPicker(
                input: input,
                selected: selected,
                history: ['大学生活', for (var i = 0; i < 10; i++) '历史$i'],
                onManage: () {},
                onChanged: (names) => setState(() => selected = names),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '#大学 ',
          composing: TextRange(start: 1, end: 4),
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      await tester.pump();
      expect(selected, isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(selected, ['大学']);
      await tester.enterText(find.byType(TextField), '#未完成');
      await tester.tap(find.byTooltip('输入井号添加标签'));
      await tester.pumpAndSettle();
      expect(input.text, '#未完成');
      await tester.enterText(find.byType(TextField), '#下一项#');
      await tester.pumpAndSettle();
      expect(selected, ['大学', '下一项']);
      expect(input.text, '#');
      await tester.tap(find.byTooltip('移除 #大学'));
      await tester.pumpAndSettle();
      expect(selected, ['下一项']);
      await tester.enterText(find.byType(TextField), '#未完成');
      await tester.tap(find.byTooltip('选择历史标签'));
      await tester.pumpAndSettle();
      expect(find.text('选择历史标签'), findsOneWidget);
      expect(selected, ['下一项']);
      expect(input.text, '#未完成');
      final historySearch = find.widgetWithText(TextField, '搜索历史标签');
      await tester.enterText(historySearch, '不存在');
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的历史标签'), findsOneWidget);
      await tester.enterText(historySearch, '＃历史9');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, '#历史9'));
      await tester.pumpAndSettle();
      expect(selected, ['下一项', '历史9']);
      expect(input.text, '#未完成');
      await tester.tap(find.byTooltip('选择历史标签'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(selected, ['下一项', '历史9']);
      await tester.tap(find.widgetWithText(ActionChip, '#大学生活'));
      await tester.pumpAndSettle();
      expect(selected, ['下一项', '历史9', '大学生活']);
      expect(input.text, '#未完成');
      expect(find.textContaining('历史标签 ·'), findsNothing);
      expect(find.textContaining('创建 #'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      input.dispose();
    },
  );
  test('hashtag input handles Chinese, adjacent hashes and deduplication', () {
    expect(parseTagNames('#大学生活 #志愿#大学生活，＃项目'), ['大学生活', '志愿', '项目']);
    expect(parseTagNames('#'), isEmpty);
    expect(() => parseTagNames('#${'长' * 65}'), throwsFormatException);
    expect(note('a', ['大学生活']).matches('#大学生活'), isTrue);
  });
  test('history survives removing a tag from a record and deleting its last record', () async {
    final c = DemoController()
      ..entries = [
        note('one', ['曾经用过']),
      ];
    await c.save(note('one', []), baseRevision: 0);
    expect(c.knownTags, ['曾经用过']);
    await c.deleteEntry(c.entry('one')!);
    expect(c.knownTags, ['曾经用过']);
    final catalog = c.entry(ArchiveActions.tagCatalogId)!;
    expect(catalog.isRecord, isFalse);
    expect(Entry.fromJson(catalog.id, catalog.toJson()).kind, 'tag_catalog');
    expect(ArchiveStats(c.entries).records, 0);
    c.dispose();
  });
  test(
    'rename merges labels across records while preserving all other fields',
    () async {
      final c = DemoController()
        ..entries = [
          note('one', ['旧标签', '新标签']),
          note('two', ['旧标签']),
        ];
      final before = c.entry('one')!.toJson()
        ..remove('tags')
        ..remove('updatedAt');
      expect(await c.renameTag('旧标签', '#新标签'), 2);
      expect(c.entry('one')!.tags, ['新标签']);
      expect(c.entry('two')!.tags, ['新标签']);
      expect(c.knownTags, ['新标签']);
      expect(
        c.entry('one')!.toJson()
          ..remove('tags')
          ..remove('updatedAt'),
        before,
      );
      expect(await c.deleteTag('新标签'), 2);
      expect(c.knownTags, isEmpty);
      expect(c.entry('one')!.plainText, '完整的正文\n');
      c.dispose();
    },
  );
  test(
    'partial tag update can be retried without losing newer record content',
    () async {
      final c = FailingTagsController()
        ..entries = [
          note('one', ['旧']),
          note('two', ['旧']),
        ]
        ..failOn = 'two';
      await expectLater(c.renameTag('旧', '新'), throwsStateError);
      expect(c.entry('one')!.tags, ['新']);
      expect(c.entry('two')!.tags, ['旧']);
      c.failOn = null;
      expect(await c.renameTag('旧', '新'), 1);
      expect(c.knownTags, ['新']);
      expect(c.entry('two')!.plainText, '完整的正文\n');
      c.dispose();
    },
  );
  testWidgets(
    'hash input, historical choices and manager keep a draft saveable',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = DemoController()
        ..entries = [
          note('one', ['大学生活']),
          note('two', ['志愿']),
        ];
      await tester.pumpWidget(
        MaterialApp(
          theme: archiveTheme().copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EntryEditor(controller: c, entry: c.entry('one')),
                  ),
                ),
                child: const Text('打开编辑'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开编辑'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '未保存的标题');
      await tester.tap(find.text('标签与关联'));
      await tester.pumpAndSettle();
      final tagField = find.widgetWithText(TextField, '输入 # 创建新标签，回车或空格确认');
      await tester.enterText(tagField, '#新想法');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, '#新想法'), findsOneWidget);
      await tester.tap(find.widgetWithText(ActionChip, '#志愿'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, '#志愿'), findsOneWidget);
      await tester.tap(find.text('管理标签'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('管理 #大学生活'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名 / 合并'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '标签名称'), '校园');
      await tester.tap(find.text('保存名称'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, '#校园'), findsOneWidget);
      expect(find.text('未保存的标题'), findsOneWidget);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(c.entry('one')!.title, '未保存的标题');
      expect(c.entry('one')!.tags, ['校园', '新想法', '志愿']);
      expect(c.knownTags, containsAll(['校园', '新想法', '志愿']));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
    },
  );
}
