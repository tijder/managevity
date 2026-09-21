import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/heatmap.dart';
import '../providers/content_providers.dart';
import '../providers/lessons_provider.dart';
import '../widgets/async_view.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';
import '../widgets/refreshable.dart';

@RoutePage()
class BusyScreen extends ConsumerWidget {
  const BusyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = dayOf(DateTime.now());
    final day = ref.watch(heatmapDayProvider(today));
    final week = ref.watch(heatmapWeekProvider);

    Future<void> refresh() async {
      ref.invalidate(heatmapDayProvider(today));
      ref.invalidate(heatmapWeekProvider);
      await ref.read(heatmapWeekProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.busyTitle),
        actions: [RefreshAction(onRefresh: refresh)],
      ),
      body: Refreshable(
        onRefresh: refresh,
        child: ResponsiveListView(
          maxWidth: 1200,
          children: [
            // Two cards side by side as soon as there is room, otherwise stacked.
            CardGrid(
              minTileWidth: 460,
              maxColumns: 2,
              children: [
                _ChartCard(
                  title: l10n.busyDay,
                  child: SizedBox(
                    height: 200,
                    child: AsyncView(
                      value: day,
                      placeholder: placeholderHeatmapDay,
                      onRetry: () => ref.invalidate(heatmapDayProvider(today)),
                      builder: (cells) => cells.isEmpty
                          ? Center(child: Text(l10n.busyEmpty))
                          : _DayBars(cells: cells, currentHour: DateTime.now().hour),
                    ),
                  ),
                ),
                _ChartCard(
                  title: l10n.busyWeek,
                  child: AsyncView(
                    value: week,
                    placeholder: placeholderHeatmapWeek,
                    onRetry: () => ref.invalidate(heatmapWeekProvider),
                    builder: (cells) => cells.isEmpty
                        ? Center(child: Text(l10n.busyEmpty))
                        : _WeekGrid(cells: cells),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class _DayBars extends StatelessWidget {
  const _DayBars({required this.cells, required this.currentHour});

  final List<HeatmapCell> cells;
  final int currentHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = [...cells]..sort((a, b) => a.hour.compareTo(b.hour));
    final max = sorted.fold<double>(0, (m, c) => c.value > m ? c.value : m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final cell in sorted)
          Expanded(
            child: Tooltip(
              // The API gives a number without a unit; only the ratio means anything.
              message:
                  '${cell.hour}:00 – ${cell.hour + 1}:00\n'
                  '${max == 0 ? 0 : (cell.value / max * 100).round()}%',
              excludeFromSemantics: true,
              child: Semantics(
                label: '${cell.hour}:00, ${max == 0 ? 0 : (cell.value / max * 100).round()}%',
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        // The bars grow from the ground up to their value, the first time too:
                        // the content replaces the skeleton, so an implicit animation would
                        // have nothing to animate.
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0.02,
                            end: max == 0 ? 0.02 : (cell.value / max).clamp(0.02, 1.0),
                          ),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                          builder: (context, factor, child) => FractionallySizedBox(
                            alignment: Alignment.bottomCenter,
                            heightFactor: factor,
                            child: child,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: cell.hour == currentHour
                                  ? scheme.primary
                                  : scheme.primaryContainer,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 14,
                        child: Text(
                          cell.hour % 3 == 0 ? '${cell.hour}' : '',
                          style: theme.textTheme.labelSmall,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.cells});

  final List<HeatmapCell> cells;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = {for (final c in cells) ?c.day}.toList()..sort();
    final slots = {for (final c in cells) c.hour}.toList()..sort();
    final max = cells.fold<double>(0, (m, c) => c.value > m ? c.value : m);
    final byKey = {for (final c in cells) (c.day, c.hour): c.value};
    // The numbering of `sortday` is documented nowhere; 1 = Monday (7 = Sunday) matches
    // what the API returns.
    final names = DateFormat.E(locale).dateSymbols.STANDALONEWEEKDAYS;
    final today = DateTime.now().weekday;

    // Three parts of the day get a name; with any other division the number stays.
    final parts = [l10n.busyMorning, l10n.busyAfternoon, l10n.busyEvening];
    String slotName(int index) => slots.length == 3 ? parts[index] : '${slots[index]}';

    Widget cell(int day, int slot) {
      // The loading shape has no values: neutral boxes, no made-up "Average".
      final value = identical(cells, placeholderHeatmapWeek) ? null : byKey[(day, slot)];
      final share = value == null || max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
      final (label, background, foreground) = switch (share) {
        >= 0.66 => (l10n.busyBusy, scheme.primary, scheme.onPrimary),
        >= 0.33 => (l10n.busyNormal, scheme.primaryContainer, scheme.onPrimaryContainer),
        _ => (l10n.busyQuiet, scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      };
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          height: 40,
          margin: const EdgeInsets.all(2),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
          child: Text(
            value == null ? '–' : label,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 88),
            for (var i = 0; i < slots.length; i++)
              Expanded(
                child: Text(
                  slotName(i),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (final day in days)
          Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  names[day % 7],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: day == today ? FontWeight.bold : null,
                    color: day == today ? scheme.primary : null,
                  ),
                ),
              ),
              for (final slot in slots) cell(day, slot),
            ],
          ),
        const SizedBox(height: 8),
        Text(l10n.busyWeekHint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
