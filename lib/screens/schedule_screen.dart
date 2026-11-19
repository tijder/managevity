import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/lesson.dart';
import '../providers/lessons_provider.dart';
import '../router/app_router.dart';
import '../utils/dates.dart';
import '../widgets/async_view.dart';
import '../widgets/placeholders.dart';
import '../widgets/lesson_card.dart';
import '../widgets/responsive.dart';
import '../widgets/refreshable.dart';

@RoutePage()
class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  static const _daysAhead = 14;

  /// How far ahead the date picker goes; a gym rarely publishes more than a few months.
  static const _pickerDays = 180;
  late DateTime _day = dayOf(DateTime.now());
  String? _activity;
  bool _showEarlier = false;

  void _select(DateTime day) => setState(() {
    _day = day;
    _showEarlier = false;
  });

  Future<void> _pickDate(DateTime today) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: today,
      lastDate: addDays(today, _pickerDays),
    );
    if (picked != null && mounted) _select(dayOf(picked));
  }

  // The day buttons start at today. Coming back after midnight, "today" has moved on: build
  // again so the selection moves with it.
  late final _lifecycle = AppLifecycleListener(onResume: () => setState(() {}));

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = dayOf(DateTime.now());
    // A day that has passed has no button any more; without this nothing would be selected.
    if (_day.isBefore(today)) _day = today;
    final lessons = ref.watch(scheduleProvider(_day));

    Future<void> refresh() => refreshSchedule(ref, _day);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabSchedule),
        actions: [RefreshAction(onRefresh: refresh)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SizedBox(
            height: 56,
            // The same column as the lessons below, so that on a wide screen the buttons do
            // not stick to the left while the content is centred.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = ((constraints.maxWidth - 1200) / 2).clamp(12.0, double.infinity) + 4;
                // A date picker for anything beyond the two weeks of buttons. In front, where
                // it is in view; once a far day is picked it shows that day, selected.
                final far = !_day.isBefore(addDays(today, _daysAhead));
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: side, vertical: 8),
                  itemCount: _daysAhead + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return ChoiceChip(
                        avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                        showCheckmark: false,
                        tooltip: l10n.schedulePickDate,
                        label: Text(
                          far ? DateFormat.MMMEd(locale).format(_day) : l10n.schedulePickDate,
                        ),
                        selected: far,
                        onSelected: (_) => _pickDate(today),
                      );
                    }
                    final day = addDays(today, i - 1);
                    return ChoiceChip(
                      label: Text(i == 1 ? l10n.today : DateFormat.MMMEd(locale).format(day)),
                      selected: day == _day,
                      onSelected: (_) => _select(day),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
      body: Refreshable(
        onRefresh: refresh,
        child: AsyncView(
          value: lessons,
          placeholder: placeholderLessons,
          onRetry: () => unawaited(refreshSchedule(ref, _day).then((_) {}, onError: (_) {})),
          builder: (all) {
            final activities = {for (final l in all) ?l.activity}.toList()..sort();
            final activity = activities.contains(_activity) ? _activity : null;
            // What has already started is of no use for booking and would otherwise be the
            // first thing on screen all evening: folded away behind a button.
            final earlier = <Lesson>[], upcoming = <Lesson>[];
            for (final l in all) {
              if (activity != null && l.activity != activity) continue;
              (l.hasStarted ? earlier : upcoming).add(l);
            }
            if (all.isEmpty) return EmptyView(l10n.scheduleEmpty);
            Widget cards(List<Lesson> lessons) => CardGrid(
              children: [
                for (final lesson in lessons)
                  LessonCard(lesson: lesson, onTap: () => openLesson(context, ref, lesson)),
              ],
            );
            return ResponsiveListView(
              maxWidth: 1200,
              children: [
                if (activities.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          label: Text(l10n.scheduleFilterAll),
                          selected: activity == null,
                          onSelected: (_) => setState(() => _activity = null),
                        ),
                        for (final a in activities)
                          FilterChip(
                            label: Text(a),
                            selected: a == activity,
                            onSelected: (_) => setState(() => _activity = a),
                          ),
                      ],
                    ),
                  ),
                if (earlier.isNotEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showEarlier = !_showEarlier),
                      icon: Icon(_showEarlier ? Icons.expand_less : Icons.expand_more),
                      label: Text(l10n.scheduleEarlier(earlier.length)),
                    ),
                  ),
                if (_showEarlier) cards(earlier),
                if (upcoming.isEmpty && earlier.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Text(
                      l10n.scheduleNoMoreToday,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                cards(upcoming),
              ],
            );
          },
        ),
      ),
    );
  }
}
