import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'archive_actions.dart';
import 'calendar_export.dart';
import 'editor.dart';
import 'model.dart';
import 'overview.dart';
import 'app_language.dart';

List<Entry> scheduleOn(Iterable<Entry> entries, DateTime day) {
  final begin = calendarDay(day);
  final next = DateTime(begin.year, begin.month, begin.day + 1);
  return entries.where((e) {
    if (e.kind != 'activity' || e.scheduleDate == null) return false;
    final start = e.scheduleDate!;
    final end = e.endsAt ?? start.add(const Duration(hours: 1));
    return start.isBefore(next) && end.isAfter(begin);
  }).toList()..sort((a, b) => a.scheduleDate!.compareTo(b.scheduleDate!));
}

class SchedulePlanner extends StatefulWidget {
  const SchedulePlanner({
    super.key,
    required this.controller,
    required this.onOpen,
  });
  final ArchiveActions controller;
  final ValueChanged<Entry> onOpen;
  @override
  State<SchedulePlanner> createState() => _SchedulePlannerState();
}

class _SchedulePlannerState extends State<SchedulePlanner> {
  DateTime selected = calendarDay(DateTime.now());
  DateTime focused = DateTime.now();
  CalendarFormat format = CalendarFormat.month;

  Future<void> add() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditor(
          controller: widget.controller,
          kind: 'activity',
          initialDate: selected,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.controller.entries;
    final rows = scheduleOn(entries, selected);
    final unscheduled = entries
        .where((e) => e.kind == 'activity' && e.scheduleDate == null)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(context.t('把重要的事，放进自己的节奏里。')),
                  FilledButton.tonalIcon(
                    onPressed: add,
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(context.t('添加日程')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: TableCalendar<Entry>(
                    locale: context.english ? 'en_US' : 'zh_CN',
                    firstDay: DateTime(2000),
                    lastDay: DateTime(2100, 12, 31),
                    focusedDay: focused,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    calendarFormat: format,
                    availableCalendarFormats: {
                      CalendarFormat.month: context.t('月'),
                      CalendarFormat.twoWeeks: context.t('双周'),
                      CalendarFormat.week: context.t('周'),
                    },
                    selectedDayPredicate: (day) => isSameDay(day, selected),
                    eventLoader: (day) => scheduleOn(entries, day),
                    onDaySelected: (day, focus) => setState(() {
                      selected = calendarDay(day);
                      focused = focus;
                    }),
                    onPageChanged: (day) => focused = day,
                    onFormatChanged: (value) => setState(() => format = value),
                    headerStyle: const HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: true,
                      formatButtonShowsNext: false,
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: .65),
                        shape: BoxShape.circle,
                      ),
                      outsideDaysVisible: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.english
                          ? '${MaterialLocalizations.of(context).formatMediumDate(selected)} · Timeline'
                          : '${selected.month} 月 ${selected.day} 日 · 时间轴',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      selected = calendarDay(DateTime.now());
                      focused = selected;
                    }),
                    child: Text(context.t('回到今天')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                Card(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 32),
                        const SizedBox(height: 12),
                        Text(context.t('这一天还很空，留给自己安排。')),
                        TextButton(
                          onPressed: add,
                          child: Text(context.t('在这天添加日程')),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final entry in rows)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          '${entry.scheduleDate!.hour.toString().padLeft(2, '0')}:${entry.scheduleDate!.minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: entry.status == ActivityStatus.completed
                            ? theme.colorScheme.secondaryContainer.withValues(
                                alpha: .35,
                              )
                            : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          title: Text(
                            entry.title.isEmpty
                                ? context.t('未命名日程')
                                : entry.title,
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            '${context.t(entry.status.label)} · ${entry.startsAt == null
                                ? context.t('提醒 / 截止时间')
                                : entry.endsAt == null
                                ? context.t('已安排')
                                : '${context.t('至 ')}${dateLabel(entry.endsAt!)}'}\n${entry.reminderTarget == 'system' ? context.t('系统日历 · 可添加副本') : context.t('静档内提醒')}',
                          ),
                          onTap: () => widget.onOpen(entry),
                          trailing: IconButton(
                            tooltip: context.t('添加到系统日历'),
                            onPressed: entry.status == ActivityStatus.cancelled
                                ? null
                                : () => exportToCalendar(context, entry),
                            icon: const Icon(Icons.calendar_month_outlined),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (unscheduled.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(context.t('还没定时间'), style: theme.textTheme.titleLarge),
                for (final entry in unscheduled)
                  Card(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(
                        entry.title.isEmpty ? context.t('未命名日程') : entry.title,
                      ),
                      subtitle: Text(context.t(entry.status.label)),
                      onTap: () => widget.onOpen(entry),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
