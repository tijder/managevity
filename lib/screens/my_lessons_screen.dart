import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../utils/errors.dart';
import '../models/lesson.dart';
import '../providers/lessons_provider.dart';
import '../router/app_router.dart';
import '../widgets/async_view.dart';
import '../widgets/placeholders.dart';
import '../widgets/lesson_card.dart';
import '../widgets/responsive.dart';
import '../widgets/refreshable.dart';

@RoutePage()
class MyLessonsScreen extends ConsumerStatefulWidget {
  const MyLessonsScreen({super.key});

  @override
  ConsumerState<MyLessonsScreen> createState() => _MyLessonsScreenState();
}

class _MyLessonsScreenState extends ConsumerState<MyLessonsScreen> {
  bool _history = false;

  Future<void> _refresh() async {
    try {
      if (_history) {
        ref.invalidate(lessonHistoryProvider);
        await ref.read(lessonHistoryProvider.future);
      } else {
        await ref.read(bookedLessonsProvider.notifier).refreshAndSync();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(context.l10n, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final AsyncValue<List<Lesson>> lessons = _history
        ? ref.watch(lessonHistoryProvider)
        : ref.watch(bookedLessonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabMyLessons),
        actions: [RefreshAction(onRefresh: _refresh)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l10n.myLessonsUpcoming)),
                  ButtonSegment(value: true, label: Text(l10n.myLessonsHistory)),
                ],
                selected: {_history},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _history = s.single),
              ),
            ),
          ),
          Expanded(
            child: Refreshable(
              onRefresh: _refresh,
              child: AsyncView(
                value: lessons,
                placeholder: placeholderLessons,
                onRetry: () =>
                    ref.invalidate(_history ? lessonHistoryProvider : bookedLessonsProvider),
                builder: (lessons) => lessons.isEmpty
                    ? EmptyView(_history ? l10n.myLessonsHistoryEmpty : l10n.myLessonsEmpty)
                    // Lazy: in the history every card fetches who taught the lesson itself,
                    // and that should only happen for what is in view.
                    : LazyCardGrid(
                        itemCount: lessons.length,
                        itemBuilder: (context, i) => _history
                            ? _PastLessonCard(lesson: lessons[i])
                            : LessonCard(
                                lesson: lessons[i],
                                showDate: true,
                                onTap: () =>
                                    context.router.push(LessonDetailRoute(lessonId: lessons[i].id)),
                              ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A lesson from the history. The list itself only knows name and time; trainer and room
/// are fetched once the card comes into view, and then appear by themselves.
class _PastLessonCard extends ConsumerWidget {
  const _PastLessonCard({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(pastLessonProvider(lesson.id)).value;
    return LessonCard(
      // The times and the status remain those from the list; the details only fill in.
      lesson: details?.copyWith(bookingStatus: lesson.bookingStatus) ?? lesson,
      showDate: true,
      onTap: () => context.router.push(LessonDetailRoute(lessonId: lesson.id)),
    );
  }
}
