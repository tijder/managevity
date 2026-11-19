import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
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
  late DateTime _day = dayOf(DateTime.now());
  String? _activity;

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
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: side, vertical: 8),
                  itemCount: _daysAhead,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final day = DateTime(today.year, today.month, today.day + i);
                    return ChoiceChip(
                      label: Text(i == 0 ? l10n.today : DateFormat.MMMEd(locale).format(day)),
                      selected: day == _day,
                      onSelected: (_) => setState(() => _day = day),
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
            final shown = [
              for (final l in all)
                if (activity == null || l.activity == activity) l,
            ];
            if (all.isEmpty) return EmptyView(l10n.scheduleEmpty);
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
                CardGrid(
                  children: [
                    for (final lesson in shown)
                      LessonCard(
                        lesson: lesson,
                        onTap: () => context.router.push(LessonDetailRoute(lessonId: lesson.id)),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
