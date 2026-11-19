import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/lesson.dart';
import '../utils/color.dart';

class LessonCard extends StatelessWidget {
  const LessonCard({super.key, required this.lesson, required this.onTap, this.showDate = false});

  final Lesson lesson;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat.Hm(locale);
    // The colour of the strip says which activity it is; in words too when the name of the
    // lesson does not, for whoever cannot tell the colours apart or does not see them.
    final activity = lesson.activity;
    final named =
        activity == null || lesson.description.toLowerCase().contains(activity.toLowerCase());
    final subtitle = [if (!named) activity, lesson.trainer, lesson.room].nonNulls.join(' · ');

    // A lesson that has already started is still listed but is no longer in play: quieter,
    // but in a colour that stays legible (fading the whole card did not).
    final muted = lesson.hasStarted && !showDate ? theme.colorScheme.onSurfaceVariant : null;
    final stripe = parseHexColor(lesson.color) ?? theme.colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      // One thing to a screen reader: "19:00 – 20:00, Yoga flow, Anna · Studio 2, Booked",
      // announced as a button, rather than four loose fragments.
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 6,
                    color: muted == null ? stripe : stripe.withValues(alpha: 0.5),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDate)
                            Text(
                              // The year only when it is not this year: otherwise "Monday 21
                              // September" cannot be placed in the history.
                              (lesson.start.year == DateTime.now().year
                                      ? DateFormat.MMMMEEEEd(locale)
                                      : DateFormat.yMMMMEEEEd(locale))
                                  .format(lesson.start),
                              style: theme.textTheme.labelMedium,
                            ),
                          Text(
                            '${time.format(lesson.start)} – ${time.format(lesson.end)}',
                            style: theme.textTheme.labelLarge?.copyWith(color: muted),
                          ),
                          Text(
                            lesson.description,
                            style: theme.textTheme.titleMedium?.copyWith(color: muted),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(color: muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(child: _status(l10n, theme)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(AppLocalizations l10n, ThemeData theme) {
    final scheme = theme.colorScheme;
    if (lesson.bookingStatus.isAttended) {
      return _Pill(
        icon: Icons.done_all,
        label: l10n.lessonAttended,
        background: scheme.surfaceContainerHighest,
        foreground: scheme.onSurfaceVariant,
      );
    }
    if (lesson.bookingStatus.isBooked) {
      return _Pill(
        icon: Icons.check,
        label: l10n.lessonBooked,
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      );
    }
    if (lesson.bookingStatus.isWaitingList) {
      return _Pill(
        icon: Icons.hourglass_bottom,
        label: l10n.lessonWaitingList,
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
      );
    }
    if (lesson.isFull) {
      return _Pill(
        label: l10n.lessonFull,
        background: scheme.errorContainer,
        foreground: scheme.onErrorContainer,
      );
    }
    final left = lesson.spotsLeft;
    if (left != null || lesson.participants != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            // What decides whether you can still go: the free spots. The count of people
            // going is on the detail screen, and here only when the maximum is unknown.
            left != null ? l10n.lessonSpotsFree(left) : l10n.lessonGoing(lesson.participants!),
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.background, required this.foreground, this.icon});

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 16, color: foreground), const SizedBox(width: 6)],
        Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground)),
      ],
    ),
  );
}
