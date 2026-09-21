import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/lessons_provider.dart';
import '../router/app_router.dart';
import '../widgets/async_view.dart';
import '../widgets/placeholders.dart';
import '../widgets/lesson_card.dart';
import '../widgets/responsive.dart';
import '../widgets/refreshable.dart';

@RoutePage()
class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    Future<void> refresh() => ref.refresh(likedLessonsProvider.future);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreFavourites),
        actions: [RefreshAction(onRefresh: refresh)],
      ),
      body: Refreshable(
        onRefresh: refresh,
        child: AsyncView(
          value: ref.watch(likedLessonsProvider),
          placeholder: placeholderLessons,
          onRetry: () => ref.invalidate(likedLessonsProvider),
          builder: (lessons) => lessons.isEmpty
              ? EmptyView(l10n.listEmpty)
              : ResponsiveListView(
                  maxWidth: 1200,
                  children: [
                    CardGrid(
                      children: [
                        for (final lesson in lessons)
                          LessonCard(
                            lesson: lesson,
                            showDate: true,
                            onTap: () =>
                                context.router.push(LessonDetailRoute(lessonId: lesson.id)),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
