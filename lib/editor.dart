import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:uuid/uuid.dart';

import 'ui_helpers.dart';
import 'archive_actions.dart';
import 'model.dart';
import 'theme.dart';
import 'calendar_export.dart';
import 'tags.dart';
import 'material_embed.dart';
import 'audio_notes.dart';
import 'markdown_typing.dart';
import 'app_language.dart';

class _DateHeaderCalendar extends GregorianCalendarDelegate {
  const _DateHeaderCalendar({required this.landscape, required this.english});
  final bool landscape, english;

  @override
  String formatMediumDate(DateTime date, MaterialLocalizations localizations) {
    if (english) {
      return '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][date.month - 1]} ${date.day}${landscape ? '\n' : ' '}${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1]}';
    }
    final weekday = localizations.narrowWeekdays[date.weekday % 7];
    return '${date.month}月${date.day}日${landscape ? '\n' : ' '}星期$weekday';
  }
}

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.controller,
    this.entry,
    this.kind = 'note',
    this.initialDate,
    this.onFinished,
  });
  final ArchiveActions controller;
  final Entry? entry;
  final String kind;
  final DateTime? initialDate;
  final ValueChanged<Entry?>? onFinished;
  @override
  State<EntryEditor> createState() => EntryEditorState();
}

class EntryEditorState extends State<EntryEditor> {
  final rawEditorKey = GlobalKey<EditorState>();
  final documentFocus = FocusNode();
  final documentScroll = ScrollController();
  late final title = TextEditingController(text: widget.entry?.title ?? '');
  final tags = TextEditingController();
  late List<String> selectedTags = [...?widget.entry?.tags];
  late final role = TextEditingController(text: widget.entry?.role ?? '');
  late final quill = QuillController(
    // Quill 11.6 exposes plain external paste through this pinned experimental API.
    config: const QuillControllerConfig(
      // ignore: experimental_member_use
      clipboardConfig: QuillClipboardConfig(
        // ignore: experimental_member_use
        enableExternalRichPaste: false,
      ),
    ),
    document: widget.entry == null
        ? Document()
        : Document.fromJson(widget.entry!.delta),
    selection: const TextSelection.collapsed(offset: 0),
  );
  late int baseRevision = widget.entry == null
      ? 0
      : widget.controller.revisionOf(widget.entry!.id);
  late ActivityStatus status =
      widget.entry?.status ?? ActivityStatus.interested;
  late DateTime? deadline = widget.entry?.deadline;
  late DateTime? reminder = widget.entry?.reminder;
  late DateTime? startsAt =
      widget.entry?.startsAt ??
      (widget.initialDate == null
          ? null
          : DateTime(
              widget.initialDate!.year,
              widget.initialDate!.month,
              widget.initialDate!.day,
              9,
            ));
  late DateTime? endsAt = widget.entry?.endsAt;
  late String reminderTarget =
      widget.entry?.reminderTarget ??
      (widget.kind == 'activity' ? 'system' : 'app');
  late String? activityId = widget.entry?.activityId;
  late List<Attachment> attachments = [...?widget.entry?.attachments];
  bool busy = false;
  bool changed = false;
  bool allowPop = false;
  bool formatting = false;
  bool askingToLeave = false;
  bool pendingMarkdown = false;
  ValueNotifier<TextRange>? compositionRange;
  StreamSubscription<dynamic>? changes;
  String get kind => widget.entry?.kind ?? widget.kind;
  bool get activity => kind == 'activity';
  String get heading => switch (kind) {
    'activity' => '活动报名',
    'experience' => '留经历',
    'project' => '存项目',
    _ => '写日记',
  };
  String get titleLabel => switch (kind) {
    'activity' => '活动名称',
    'experience' => '经历名称',
    'project' => '项目名称',
    _ => '标题（可以不填）',
  };

  @override
  void initState() {
    super.initState();
    for (final field in [title, tags, role]) {
      field.addListener(markChanged);
    }
    changes = quill.document.changes.listen((change) {
      markChanged();
      if (change.source == ChangeSource.local &&
          !quill.document.hasRedo &&
          change.change.toList().any(
            (op) => op.isInsert && op.data is String,
          )) {
        pendingMarkdown = true;
        final raw = rawEditorKey.currentState;
        if (raw is QuillRawEditorState &&
            compositionRange != raw.composingRange) {
          compositionRange?.removeListener(markdownCompositionChanged);
          compositionRange = raw.composingRange;
          compositionRange!.addListener(markdownCompositionChanged);
        }
        scheduleMicrotask(formatPendingMarkdown);
      }
    });
  }

  void formatPendingMarkdown() {
    if (!mounted || busy || !pendingMarkdown || !widget.controller.unlocked) {
      return;
    }
    if (compositionRange?.value.isCollapsed == false) return;
    pendingMarkdown = false;
    // Undo may restore literal Markdown; only a new edit should convert it again.
    if (quill.document.hasRedo) return;
    applyMarkdownTyping(quill);
  }

  void markdownCompositionChanged() => scheduleMicrotask(formatPendingMarkdown);

  void markChanged() {
    if (!changed && mounted) setState(() => changed = true);
  }

  void focusDocument() {
    documentFocus.requestFocus();
    rawEditorKey.currentState?.requestKeyboard();
  }

  void setAccessibleBody(String text) {
    // Replace only changed graphemes, preserving surrounding rich-text styles.
    final previous = quill.document.toPlainText().characters.toList();
    final nextText = text.endsWith('\n') ? text : '$text\n';
    final next = nextText.characters.toList();
    var prefix = 0;
    var offset = 0;
    while (prefix < previous.length &&
        prefix < next.length &&
        previous[prefix] == next[prefix]) {
      offset += previous[prefix].length;
      prefix++;
    }
    var suffix = 0;
    while (suffix < previous.length - prefix &&
        suffix < next.length - prefix &&
        previous[previous.length - suffix - 1] ==
            next[next.length - suffix - 1]) {
      suffix++;
    }
    final removed = previous
        .sublist(prefix, previous.length - suffix)
        .join()
        .length;
    final inserted = next.sublist(prefix, next.length - suffix).join();
    if (removed == 0 && inserted.isEmpty) return;
    documentFocus.requestFocus();
    quill.replaceText(
      offset,
      removed,
      inserted,
      TextSelection.collapsed(offset: nextText.length - 1),
    );
  }

  Future<void> manageTags() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TagManager(
          controller: widget.controller,
          onTagChanged: (oldName, newName) {
            if (!mounted) return;
            setState(() {
              selectedTags = selectedTags
                  .map((name) => name == oldName ? newName : name)
                  .whereType<String>()
                  .toSet()
                  .toList();
              try {
                final pending = parseTagNames(tags.text);
                if (pending.contains(oldName)) {
                  selectedTags = {
                    ...selectedTags,
                    ...pending
                        .map((name) => name == oldName ? newName : name)
                        .whereType<String>(),
                  }.toList();
                  tags.clear();
                }
              } on FormatException {
                /* Keep invalid draft input visible for correction. */
              }
              changed = true;
            });
          },
        ),
      ),
    );
    if (!mounted) return;
    final initial = widget.entry;
    final current = initial == null
        ? null
        : widget.controller.entry(initial.id);
    if (initial != null && current != null) {
      final before = initial.toJson()
        ..remove('tags')
        ..remove('updatedAt');
      final after = current.toJson()
        ..remove('tags')
        ..remove('updatedAt');
      // Rebase only our tag edits; concurrent changes to other fields still conflict.
      if (jsonEncode(before) == jsonEncode(after)) {
        baseRevision = widget.controller.revisionOf(initial.id);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    changes?.cancel();
    compositionRange?.removeListener(markdownCompositionChanged);
    title.dispose();
    tags.dispose();
    role.dispose();
    documentFocus.dispose();
    documentScroll.dispose();
    quill.dispose();
    super.dispose();
  }

  Future<bool> confirmDiscard() async {
    if (busy || askingToLeave) return false;
    if (changed) {
      askingToLeave = true;
      try {
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.t('放弃尚未保存的修改？')),
            content: Text(context.t('留在这里可以继续记录。')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t('继续记录')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.t('放弃修改')),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return false;
      } finally {
        askingToLeave = false;
      }
    }
    return true;
  }

  Future<void> close() async {
    if (!await confirmDiscard() || !mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!(null);
      return;
    }
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<DateTime?> pickTime(DateTime? initial) async {
    final start = initial ?? DateTime.now().add(const Duration(hours: 1));
    final date = await showDialog<DateTime>(
      context: context,
      builder: (context) => DatePickerTheme(
        data: DatePickerTheme.of(
          context,
        ).copyWith(headerHeadlineStyle: Theme.of(context).textTheme.titleLarge),
        child: DatePickerDialog(
          initialDate: start,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          calendarDelegate: _DateHeaderCalendar(
            english: context.english,
            landscape:
                MediaQuery.orientationOf(context) == Orientation.landscape,
          ),
        ),
      ),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    return time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> attach() async {
    setState(() => busy = true);
    try {
      final files = await FilePicker.pickFiles();
      for (final file in files) {
        final chunks = BytesBuilder(copy: false);
        await for (final chunk in file.readAsByteStream()) {
          if (chunks.length + chunk.length > 20 * 1024 * 1024) {
            throw const FormatException('单个附件最多 20 MiB');
          }
          chunks.add(chunk);
        }
        final bytes = chunks.takeBytes();
        try {
          final attachment = await widget.controller.addAttachment(
            file.name,
            bytes,
          );
          if (mounted) {
            setState(() {
              attachments.add(attachment);
              changed = true;
            });
          }
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {
        /* Some desktop pickers do not create a cache. */
      }
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> recordAudio() async {
    setState(() => busy = true);
    try {
      final file = await recordOriginalAudio(context, widget.controller);
      if (file == null || !mounted || !widget.controller.unlocked) return;
      setState(() {
        attachments.add(file);
        changed = true;
      });
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    formatPendingMarkdown();
    setState(() => busy = true);
    try {
      if (title.text.trim().isEmpty &&
          quill.document.toPlainText().trim().isEmpty &&
          attachments.isEmpty) {
        throw const FormatException('写下一句话，或添加一份附件，就可以保存');
      }
      final now = DateTime.now();
      if (endsAt != null && (startsAt == null || !endsAt!.isAfter(startsAt!))) {
        throw const FormatException('结束时间需要晚于开始时间');
      }
      if (activity && startsAt == null) {
        throw const FormatException('请先设置日程开始时间');
      }
      final saved = Entry(
        id: widget.entry?.id ?? const Uuid().v4(),
        title: title.text.trim(),
        delta: quill.document.toDelta().toJson(),
        kind: kind,
        createdAt: widget.entry?.createdAt ?? now,
        updatedAt: now,
        tags: {...selectedTags, ...parseTagNames(tags.text)}.toList(),
        role: role.text.trim(),
        attachments: attachments,
        activityId: activityId,
        status: status,
        deadline: deadline,
        reminder: reminder,
        startsAt: startsAt,
        endsAt: endsAt,
        reminderTarget: reminderTarget,
      );
      await widget.controller.save(saved, baseRevision: baseRevision);
      if (!mounted) return;
      if (activity && reminderTarget == 'system') {
        await exportToCalendar(context, saved);
        if (!mounted) return;
      }
      setState(() {
        changed = false;
        allowPop = true;
      });
      if (widget.onFinished != null) {
        widget.onFinished!(saved);
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void markdownHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.t('Markdown 快捷排版')),
      content: SingleChildScrollView(
        child: Text(
          context.english
              ? 'At the start of a line, type a marker followed by Space:\n# Heading 1 · ## Heading 2 · ### Heading 3\n- Bullet · 1. Numbered list · > Quote\n[ ] To-do · [x] Done · three backticks for a code block\n\nUse pairs:\n**bold** · *italic* · ~~strikethrough~~ · backticks for inline code\n\nYou can also open the formatting toolbar. Shortcuts apply only to new input; existing records are kept. Conversion pauses during input-method composition.'
              : '行首输入符号后加空格：\n# 一级标题 · ## 二级标题 · ### 三级标题\n- 无序列表 · 1. 有序列表 · > 引用\n[ ] 待办 · [x] 已完成 · 三个反引号加空格为代码块\n\n成对输入：\n**粗体** · *斜体* · ~~删除线~~ · 单反引号包围行内代码\n\n也可以打开排版工具。只对新输入排版，不改写已有记录；中文输入组合中暂停转换。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('知道了')),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final activities = widget.controller.entries
        .where((e) => e.kind == 'activity')
        .toList();
    final metadata = <Widget>[
      TagPicker(
        input: tags,
        selected: selectedTags,
        history: widget.controller.knownTags,
        onManage: manageTags,
        onChanged: (names) => setState(() {
          selectedTags = names;
          changed = true;
        }),
      ),
      const SizedBox(height: 16),
      if (activity) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(context.t('开始时间')),
          subtitle: Text(
            startsAt == null ? context.t('请选择日期和时间') : dateLabel(startsAt!),
          ),
          onTap: () async {
            final time = await pickTime(startsAt);
            if (time != null && mounted) {
              setState(() {
                startsAt = time;
                changed = true;
              });
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: Text(context.t('结束时间')),
          subtitle: Text(
            endsAt == null ? context.t('默认持续 1 小时') : dateLabel(endsAt!),
          ),
          onTap: () async {
            final time = await pickTime(
              endsAt ?? startsAt?.add(const Duration(hours: 1)),
            );
            if (time != null && mounted) {
              setState(() {
                endsAt = time;
                changed = true;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'system',
              label: Text(context.t('系统日历')),
              icon: Icon(Icons.calendar_month_outlined),
            ),
            ButtonSegment(
              value: 'app',
              label: Text(context.t('静档内提醒')),
              icon: Icon(Icons.notifications_none),
            ),
          ],
          selected: {reminderTarget},
          onSelectionChanged: (value) => setState(() {
            reminderTarget = value.first;
            changed = true;
          }),
        ),
        const SizedBox(height: 8),
        Text(
          reminderTarget == 'system'
              ? context.t('保存后由你确认添加到系统日历；也可以先只留在静档。')
              : context.t('由静档在这台设备发送通知；需要开启通知权限。'),
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ActivityStatus>(
          initialValue: status,
          decoration: InputDecoration(labelText: context.t('参与状态')),
          items: ActivityStatus.values
              .map(
                (s) =>
                    DropdownMenuItem(value: s, child: Text(context.t(s.label))),
              )
              .toList(),
          onChanged: (s) => setState(() {
            status = s!;
            changed = true;
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: role,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: context.t('承担的工作与经历'),
            hintText: context.t('做了什么、负责什么，都可以慢慢补充'),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(context.t('报名截止时间')),
          subtitle: Text(
            deadline == null ? context.t('尚未设置') : dateLabel(deadline!),
          ),
          onTap: () async {
            final time = await pickTime(deadline);
            if (time != null && mounted) {
              setState(() {
                deadline = time;
                changed = true;
              });
            }
          },
          trailing: deadline == null
              ? null
              : IconButton(
                  tooltip: context.t('清除截止时间'),
                  onPressed: () => setState(() {
                    deadline = null;
                    changed = true;
                  }),
                  icon: const Icon(Icons.close),
                ),
        ),
      ] else ...[
        DropdownButtonFormField<String>(
          initialValue: activityId ?? '',
          isExpanded: true,
          decoration: InputDecoration(labelText: context.t('关联活动（可选）')),
          items: [
            DropdownMenuItem(value: '', child: Text(context.t('不关联'))),
            ...activities.map(
              (e) => DropdownMenuItem(
                value: e.id,
                child: Text(e.title, overflow: TextOverflow.ellipsis),
              ),
            ),
            if (activityId != null &&
                !activities.any((e) => e.id == activityId))
              DropdownMenuItem(
                value: activityId,
                child: Text(context.t('原活动已删除')),
              ),
          ],
          onChanged: (id) => setState(() {
            activityId = id == '' ? null : id;
            changed = true;
          }),
        ),
      ],
    ];
    final content = AbsorbPointer(
      absorbing: busy,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.onFinished == null ? 860 : double.infinity,
          ),
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('document-title'),
                      controller: title,
                      maxLength: 200,
                      minLines: 1,
                      maxLines: null,
                      style: activity
                          ? null
                          : Theme.of(context).textTheme.headlineSmall,
                      decoration: activity
                          ? InputDecoration(
                              labelText: context.t(titleLabel),
                              counterText: '',
                            )
                          : InputDecoration(
                              labelText: context.t(titleLabel),
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                              floatingLabelStyle: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                              labelStyle: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Theme.of(context).hintColor,
                                  ),
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                    ),
                  ),
                  if (widget.onFinished != null) ...[
                    const ArchiveLanguageSwitch(),
                    TextButton(
                      onPressed: busy ? null : save,
                      child: Text(busy ? context.t('处理中…') : context.t('保存')),
                    ),
                    IconButton(
                      onPressed: busy ? null : close,
                      tooltip: context.t('结束编辑'),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (!activity) ...[
                Wrap(
                  spacing: 10,
                  children: [
                    Text(dateLabel(widget.entry?.createdAt ?? DateTime.now())),
                    Text(
                      widget.entry == null
                          ? switch (kind) {
                              'experience' => context.t('经历'),
                              'project' => context.t('项目'),
                              _ => context.t('日记'),
                            }
                          : context.t(widget.entry!.kindLabel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ExpansionTile(
                  key: const Key('record-metadata'),
                  maintainState: true,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 16),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(
                    context.t('标签与关联'),
                    style: TextStyle(fontSize: 14),
                  ),
                  subtitle: selectedTags.isEmpty
                      ? null
                      : Text(
                          selectedTags.map((tag) => '#$tag').join('  '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xff345477),
                          ),
                        ),
                  children: metadata,
                ),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => formatting = !formatting),
                      icon: const Icon(Icons.text_format),
                      label: Text(context.t('排版')),
                    ),
                    IconButton(
                      onPressed: markdownHelp,
                      tooltip: context.t('Markdown 快捷排版'),
                      icon: const Icon(Icons.help_outline, size: 18),
                    ),
                  ],
                ),
              ] else
                ...metadata,
              if (activity || formatting)
                QuillSimpleToolbar(
                  controller: quill,
                  config: const QuillSimpleToolbarConfig(
                    multiRowsDisplay: false,
                    showFontFamily: false,
                    showFontSize: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showDividers: false,
                  ),
                ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: Listenable.merge([quill, documentFocus]),
                builder: (context, _) => Semantics(
                  label: context.t('正文'),
                  excludeSemantics: true,
                  textField: true,
                  enabled: true,
                  focusable: true,
                  focused: documentFocus.hasFocus,
                  multiline: true,
                  value: quill.document.toPlainText(),
                  onFocus: focusDocument,
                  onTap: focusDocument,
                  onSetText: setAccessibleBody,
                  child: QuillEditor.basic(
                    key: const Key('document-body'),
                    controller: quill,
                    focusNode: documentFocus,
                    scrollController: documentScroll,
                    config: QuillEditorConfig(
                      editorKey: rawEditorKey,
                      scrollable: false,
                      minHeight: 220,
                      embedBuilders: [MaterialEmbedBuilder(widget.controller)],
                      unknownEmbedBuilder: const UnknownArchiveEmbedBuilder(),
                      customStyles: archiveDocumentStyles(context),
                      padding: EdgeInsets.zero,
                      placeholder: switch (kind) {
                        'experience' => context.t('参与了什么、做了什么，有哪些收获？'),
                        'project' => context.t('项目目标、你的工作、进展和成果，都可以慢慢补充。'),
                        _ => context.t('想法、困惑或开心的瞬间，都可以写在这里。'),
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!activity)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('record-original-audio'),
                    onPressed: recordAudio,
                    icon: const Icon(Icons.mic_none),
                    label: Text(context.t('留一段原声')),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.snippet_folder_outlined),
                  label: Text(context.t('插入材料引用')),
                  onPressed: () async {
                    final id = await chooseMaterial(context, widget.controller);
                    if (id == null || !mounted) return;
                    final index = quill.selection.start.clamp(
                      0,
                      quill.document.length - 1,
                    );
                    quill.replaceText(
                      index,
                      quill.selection.end - quill.selection.start,
                      BlockEmbed.custom(
                        CustomBlockEmbed(materialEmbedType, id),
                      ),
                      null,
                    );
                  },
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: attachments
                    .map(
                      (file) => InputChip(
                        label: Text(file.name),
                        avatar: Icon(
                          isAudioFile(file.name)
                              ? Icons.play_circle_outline
                              : Icons.attach_file,
                          size: 18,
                        ),
                        onPressed: isAudioFile(file.name)
                            ? () => playOriginalAudio(
                                context,
                                widget.controller,
                                file,
                              )
                            : null,
                        onDeleted: () => setState(() {
                          attachments.remove(file);
                          changed = true;
                        }),
                      ),
                    )
                    .toList(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: attach,
                  icon: const Icon(Icons.attach_file),
                  label: Text(context.t('添加照片或证明附件（每份最多 20 MiB）')),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_none),
                title: Text(context.t('给自己一个提醒')),
                subtitle: Text(
                  reminder == null ? context.t('尚未设置') : dateLabel(reminder!),
                ),
                onTap: () async {
                  final time = await pickTime(reminder);
                  if (time != null && mounted) {
                    setState(() {
                      reminder = time;
                      changed = true;
                    });
                  }
                },
                trailing: reminder == null
                    ? null
                    : IconButton(
                        tooltip: context.t('清除提醒'),
                        onPressed: () => setState(() {
                          reminder = null;
                          changed = true;
                        }),
                        icon: const Icon(Icons.close),
                      ),
              ),
              if (reminder != null &&
                  reminderTarget == 'app' &&
                  !widget.controller.notificationsEnabled)
                TextButton.icon(
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(context.t('开启此设备的通知提醒')),
                  onPressed: () async {
                    try {
                      final allowed = await widget.controller
                          .enableNotifications(true);
                      if (context.mounted) {
                        setState(() {});
                        if (!allowed) {
                          showFailure(
                            context,
                            StateError(
                              widget.controller.isDemo
                                  ? '浏览器演示不发送系统通知，安排仍会保留在此页面。'
                                  : '通知权限未开启，安排已保留；可前往系统设置开启。',
                            ),
                          );
                        }
                      }
                    } catch (error) {
                      if (context.mounted) showFailure(context, error);
                    }
                  },
                ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
    return PopScope(
      canPop: allowPop || (!changed && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(close());
      },
      child: widget.onFinished != null
          ? content
          : Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  onPressed: busy ? null : close,
                  tooltip: context.t('返回'),
                  icon: const Icon(Icons.arrow_back),
                ),
                title: Text(context.t(heading)),
                actions: [
                  const ArchiveLanguageSwitch(),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(busy ? context.t('处理中…') : context.t('保存')),
                    ),
                  ),
                ],
              ),
              body: content,
            ),
    );
  }
}

String dateLabel(DateTime value) =>
    '${value.year}.${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
