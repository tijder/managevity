import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/invoice.dart';

/// One month in the chart: what was invoiced, and which part of that is still outstanding.
class MonthTotal {
  const MonthTotal(this.month, this.paid, this.open);

  /// The first day of the month.
  final DateTime month;
  final double paid;
  final double open;

  double get total => paid + open;
}

/// The last [months] months up to and including the month of the newest invoice, including
/// the months without an invoice — a gap in the series is information. Invoices without a
/// readable date or amount are left out. Empty if there is nothing to draw.
List<MonthTotal> monthlyTotals(List<Invoice> invoices, Set<int> openIds, {int months = 12}) {
  final dated = [
    for (final i in invoices)
      if (i.dateValue != null && i.amountValue != null) i,
  ];
  if (dated.isEmpty) return const [];
  final newest = dated.map((i) => i.dateValue!).reduce((a, b) => a.isAfter(b) ? a : b);
  final oldest = dated.map((i) => i.dateValue!).reduce((a, b) => a.isBefore(b) ? a : b);
  // No further back than there are invoices: eleven empty months before a single invoice
  // say nothing.
  final span = (newest.year - oldest.year) * 12 + newest.month - oldest.month + 1;
  final count = span.clamp(1, months);

  return [
    for (var offset = count - 1; offset >= 0; offset--)
      () {
        final month = DateTime(newest.year, newest.month - offset);
        var paid = 0.0, open = 0.0;
        for (final i in dated) {
          final d = i.dateValue!;
          if (d.year != month.year || d.month != month.month) continue;
          openIds.contains(i.id) ? open += i.amountValue! : paid += i.amountValue!;
        }
        return MonthTotal(month, paid, open);
      }(),
  ];
}

class InvoiceChart extends StatelessWidget {
  const InvoiceChart({super.key, required this.invoices, required this.openIds});

  final List<Invoice> invoices;
  final Set<int> openIds;

  @override
  Widget build(BuildContext context) {
    final data = monthlyTotals(invoices, openIds);
    if (data.length < 2) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final money = NumberFormat.simpleCurrency(locale: locale, name: 'EUR');
    final wholeEuros = NumberFormat.simpleCurrency(locale: locale, name: 'EUR', decimalDigits: 0);
    final max = data.fold<double>(0, (m, d) => d.total > m ? d.total : m);
    final sum = data.fold<double>(0, (s, d) => s + d.total);
    final hasOpen = data.any((d) => d.open > 0);
    // Round steps on the axis: 10, 20, 25, 50, 100, …
    final step = _niceStep(max / 3);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.invoiceChartTitle, style: theme.textTheme.titleMedium),
            Text(
              l10n.invoiceChartTotal(money.format(sum), data.length),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: _Bars(
                data: data,
                maxY: (max / step).ceil() * step,
                step: step,
                axisLabel: wholeEuros.format,
                tooltip: (d) =>
                    '${DateFormat.yMMMM(locale).format(d.month)}\n${money.format(d.total)}'
                    '${d.open > 0 ? '\n${l10n.invoiceChartOpen}: ${money.format(d.open)}' : ''}',
                monthLabel: (i) {
                  final month = data[i].month;
                  // With many bars only every other month gets a label, plus January with
                  // the year so that a change of year is visible.
                  if (data.length > 8 && i.isOdd && month.month != 1) return '';
                  return month.month == 1
                      ? DateFormat("MMM ''yy", locale).format(month)
                      : DateFormat.MMM(locale).format(month);
                },
              ),
            ),
            if (hasOpen) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _Legend(color: scheme.primary, label: l10n.invoiceChartPaid),
                  const SizedBox(width: 16),
                  _Legend(color: scheme.error, label: l10n.invoiceChartOpen),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The bars themselves: drawn by hand from plain boxes, just like the busyness chart. No
/// charting package — a handful of bars with an axis does not need one.
class _Bars extends StatelessWidget {
  const _Bars({
    required this.data,
    required this.maxY,
    required this.step,
    required this.axisLabel,
    required this.tooltip,
    required this.monthLabel,
  });

  final List<MonthTotal> data;
  final double maxY;
  final double step;
  final String Function(double) axisLabel;
  final String Function(MonthTotal) tooltip;
  final String Function(int index) monthLabel;

  static const _axisWidth = 44.0;
  static const _labelHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final lines = (maxY / step).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotHeight = constraints.maxHeight - _labelHeight;
        final slot = (constraints.maxWidth - _axisWidth) / data.length;
        // The bars scale with the width: no thin slivers on a wide screen.
        final barWidth = (slot * 0.5).clamp(8.0, 40.0);
        return Stack(
          // The top axis label sits half above the top line; do not clip it.
          clipBehavior: Clip.none,
          children: [
            // Grid lines with their amount, from 0 at the bottom to maxY at the top.
            for (var k = 0; k <= lines; k++) ...[
              Positioned(
                left: _axisWidth,
                right: 0,
                top: plotHeight * (1 - k / lines),
                child: Container(height: 1, color: k == 0 ? scheme.outline : scheme.outlineVariant),
              ),
              Positioned(
                left: 0,
                width: _axisWidth - 8,
                top: plotHeight * (1 - k / lines) - 7,
                child: Text(axisLabel(k * step), style: labelStyle, textAlign: TextAlign.right),
              ),
            ],
            Positioned.fill(
              left: _axisWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, d) in data.indexed)
                    Expanded(
                      // To a screen reader every bar is one sentence: month, amount, what is
                      // outstanding.
                      child: Tooltip(
                        message: tooltip(d),
                        excludeFromSemantics: true,
                        child: Semantics(
                          label: tooltip(d).replaceAll('\n', ', '),
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: plotHeight,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: SizedBox(
                                      width: barWidth,
                                      height: maxY == 0 ? 0 : plotHeight * d.total / maxY,
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(4),
                                        ),
                                        // Stacked: what is outstanding on top of what is paid.
                                        child: Column(
                                          children: [
                                            if (d.open > 0)
                                              Expanded(
                                                flex: (d.open * 100).round().clamp(1, 1 << 30),
                                                child: Container(color: scheme.error),
                                              ),
                                            if (d.paid > 0)
                                              Expanded(
                                                flex: (d.paid * 100).round().clamp(1, 1 << 30),
                                                child: Container(color: scheme.primary),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: _labelHeight,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Text(
                                      monthLabel(i),
                                      style: labelStyle,
                                      softWrap: false,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

double _niceStep(double raw) {
  if (raw <= 0) return 1;
  var magnitude = 1.0;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  while (magnitude > raw) {
    magnitude /= 10;
  }
  for (final factor in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (magnitude * factor >= raw) return magnitude * factor;
  }
  return magnitude * 10;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );
}
