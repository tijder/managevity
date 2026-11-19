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
import '../widgets/confirm_action.dart';
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

  /// What the heart shows while (and after) the server is told; null follows the lesson.
  bool? _liked;
  bool _liking = false;

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
    final confirmed = await confirmAction(
      context,
      title: l10n.lessonBuyTitle,
      lines: [
        _what(lesson),
        amount == null ? l10n.lessonBuyUnknownAmount : l10n.lessonBuyAmount(amount),
      ],
      confirmLabel: l10n.lessonBuyConfirm,
    );
    return confirmed ? booked.book(lesson, buy: true) : result;
  });

  /// The lesson in one line, for a question about it: which one, and when.
  String _what(Lesson lesson) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat.Hm(locale);
    return '${lesson.description}\n${DateFormat.MMMMEEEEd(locale).format(lesson.start)}  ·  '
        '${time.format(lesson.start)} – ${time.format(lesson.end)}';
  }

  Future<void> _cancel(Lesson lesson) async {
    final l10n = context.l10n;
    final confirmed = await confirmAction(
      context,
      title: l10n.lessonCancelConfirm,
      lines: [_what(lesson)],
      confirmLabel: l10n.lessonCancel,
    );
    if (confirmed && mounted) {
      await _run(() => ref.read(bookedLessonsProvider.notifier).cancel(lesson));
    }
  }

  Future<void> _toggleLike(Lesson lesson) async {
    if (_liking) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final like = !(_liked ?? lesson.liked);
    // The heart turns at once; a second tap waits until the server has heard the first.
    setState(() {
      _liking = true;
      _liked = like;
    });
    try {
      await ref.read(apiProvider).likeLesson(lesson.id, ref.read(locationIdProvider), like: like);
      ref.invalidate(lessonProvider(lesson.id));
      ref.invalidate(likedLessonsProvider);
    } catch (e) {
      if (mounted) setState(() => _liked = null);
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final loaded = ref.watch(lessonProvider(widget.lessonId));
    // What the list knew, until the full lesson is in: the page is there at once. Nothing
    // can be done with it yet (see the button below) — a status from a list may be old.
    final preview = ref.watch(lessonPreviewsProvider)[widget.lessonId];
    final value = loaded.hasValue || loaded.hasError || preview == null
        ? loaded
        : AsyncData(preview);
    final lesson = loaded.value;
    final shown = value.value;
    final liked = _liked ?? lesson?.liked ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(shown?.description ?? ''),
        actions: [
          if (lesson != null)
            IconButton(
              tooltip: l10n.lessonLike,
              isSelected: liked,
              icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
              onPressed: () => _toggleLike(lesson),
            ),
        ],
      ),
      // The button is pinned to the bottom: with a long description you do not have to
      // scroll to be able to book.
      bottomNavigationBar: shown == null
          ? null
          : SafeArea(
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: _action(l10n, shown, enabled: lesson != null && !_busy),
                    ),
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
                      if (lesson.participants != null)
                        InfoRow(
                          icon: Icons.groups_outlined,
                          label: l10n.lessonParticipants,
                          value: switch ((lesson.maximumParticipants, lesson.spotsLeft)) {
                            (final max?, final left?) => [
                              l10n.lessonGoingOfMax(lesson.participants!, max),
                              if (lesson.isFull) l10n.lessonFull else l10n.lessonSpotsFree(left),
                            ].join(' · '),
                            _ => l10n.lessonGoing(lesson.participants!),
                          },
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

  Widget _action(AppLocalizations l10n, Lesson lesson, {required bool enabled}) {
    if (lesson.hasStarted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          lesson.isPast ? l10n.lessonPast : l10n.lessonStarted,
          textAlign: TextAlign.center,
        ),
      );
    }
    if (lesson.bookingStatus.isMine) {
      return OutlinedButton.icon(
        onPressed: enabled ? () => _cancel(lesson) : null,
        icon: const Icon(Icons.event_busy),
        label: Text(l10n.lessonCancel),
      );
    }
    final full = lesson.isFull;
    if (full && !lesson.canUseWaitingList) {
      return FilledButton(onPressed: null, child: Text(l10n.lessonFull));
    }
    return FilledButton.icon(
      onPressed: enabled ? () => _book(lesson) : null,
      icon: const Icon(Icons.event_available),
      label: Text(full ? l10n.lessonJoinWaitingList : l10n.lessonBook),
    );
  }
}
