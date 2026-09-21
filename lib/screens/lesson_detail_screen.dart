import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../utils/errors.dart';
import '../models/lesson.dart';
import '../providers/lessons_provider.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../services/sportivity_api.dart';
import '../utils/color.dart';
import '../utils/html_text.dart';
import '../widgets/async_view.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';

@RoutePage()
class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({super.key, @PathParam('id') required this.lessonId});

  final int lessonId;

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<BookingResult> Function() action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final result = await action();
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.message ?? (result.success ? l10n.actionDone : l10n.actionFailed)),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _book(Lesson lesson) => _run(() async {
    final booked = ref.read(bookedLessonsProvider.notifier);
    final result = await booked.book(lesson);
    // First without buying. Only if the API says payment is required, and only after an
    // explicit yes with the amount on screen, again with BuyLesson.
    if (result.success || !result.needsPayment || !mounted) return result;
    final amount = result.lesson?.amount ?? lesson.amount;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.lessonBuyTitle),
        content: Text(amount == null ? l10n.lessonBuyUnknownAmount : l10n.lessonBuyAmount(amount)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.back)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.lessonBuyConfirm),
          ),
        ],
      ),
    );
    return confirmed == true ? booked.book(lesson, buy: true) : result;
  });

  Future<void> _cancel(Lesson lesson) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.lessonCancelConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.back)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.lessonCancel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => ref.read(bookedLessonsProvider.notifier).cancel(lesson));
    }
  }

  Future<void> _toggleLike(Lesson lesson) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(apiProvider)
          .likeLesson(lesson.id, ref.read(locationIdProvider), like: !lesson.liked);
      ref.invalidate(lessonProvider(lesson.id));
      ref.invalidate(likedLessonsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final value = ref.watch(lessonProvider(widget.lessonId));
    final lesson = value.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson?.description ?? ''),
        actions: [
          if (lesson != null)
            IconButton(
              tooltip: l10n.lessonLike,
              icon: Icon(lesson.liked ? Icons.favorite : Icons.favorite_border),
              onPressed: () => _toggleLike(lesson),
            ),
        ],
      ),
      // The button is pinned to the bottom: with a long description you do not have to
      // scroll to be able to book.
      bottomNavigationBar: lesson == null
          ? null
          : SafeArea(
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(width: double.infinity, child: _action(l10n, lesson)),
                  ),
                ),
              ),
            ),
      body: AsyncView(
        value: value,
        placeholder: placeholderLesson,
        onRetry: () => ref.invalidate(lessonProvider(widget.lessonId)),
        builder: (lesson) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final time = DateFormat.Hm(locale);
          final accent = parseHexColor(lesson.color) ?? scheme.primary;
          // The band may have the raw lesson colour; text in that colour has to stay legible.
          final accentText = readableOn(accent, theme.brightness);
          final place = [lesson.room, lesson.locationName].nonNulls.join(', ');
          final info = lesson.additionalInformation;
          return ResponsiveListView(
            padding: 16,
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 8, color: accent),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (lesson.activity != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                lesson.activity!.toUpperCase(),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: accentText,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          Text(lesson.description, style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat.yMMMMEEEEd(locale).format(lesson.start)}  ·  '
                            '${time.format(lesson.start)} – ${time.format(lesson.end)}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (lesson.bookingStatus.isMine) ...[
                            const SizedBox(height: 12),
                            Chip(
                              avatar: Icon(
                                lesson.bookingStatus.isBooked
                                    ? Icons.check
                                    : Icons.hourglass_bottom,
                                size: 18,
                              ),
                              label: Text(
                                lesson.bookingStatus.isBooked
                                    ? l10n.lessonBooked
                                    : l10n.lessonWaitingList,
                              ),
                              backgroundColor: scheme.primaryContainer,
                              side: BorderSide.none,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      if (lesson.trainer != null)
                        InfoRow(
                          icon: Icons.person_outline,
                          label: l10n.lessonTrainer,
                          value: lesson.trainer!,
                        ),
                      if (place.isNotEmpty)
                        InfoRow(icon: Icons.place_outlined, label: l10n.lessonRoom, value: place),
                      if (lesson.spotsLeft != null)
                        InfoRow(
                          icon: Icons.groups_outlined,
                          label: l10n.lessonParticipants,
                          value: lesson.maximumParticipants == null
                              ? l10n.lessonSpots(lesson.spotsLeft!)
                              : l10n.lessonSpotsOfMax(
                                  lesson.spotsLeft!,
                                  lesson.maximumParticipants!,
                                ),
                        ),
                    ],
                  ),
                ),
              ),
              if (info != null) ...[
                SectionTitle(l10n.lessonAbout),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SelectableText(htmlToText(info), style: theme.textTheme.bodyLarge),
                ),
              ],
              if (lesson.warning != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                  child: Text(lesson.warning!, style: TextStyle(color: scheme.error)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _action(AppLocalizations l10n, Lesson lesson) {
    if (lesson.isPast) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(l10n.lessonPast, textAlign: TextAlign.center),
      );
    }
    if (lesson.bookingStatus.isMine) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : () => _cancel(lesson),
        icon: const Icon(Icons.event_busy),
        label: Text(l10n.lessonCancel),
      );
    }
    final full = lesson.full || lesson.spotsLeft == 0;
    if (full && !lesson.canUseWaitingList) {
      return FilledButton(onPressed: null, child: Text(l10n.lessonFull));
    }
    return FilledButton.icon(
      onPressed: _busy ? null : () => _book(lesson),
      icon: const Icon(Icons.event_available),
      label: Text(full ? l10n.lessonJoinWaitingList : l10n.lessonBook),
    );
  }
}
