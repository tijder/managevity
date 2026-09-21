import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../utils/errors.dart';
import '../models/invoice.dart';
import '../providers/content_providers.dart';
import '../providers/services.dart';
import '../utils/pdf_opener.dart';
import '../widgets/async_view.dart';
import '../widgets/invoice_chart.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';
import '../widgets/refreshable.dart';

@RoutePage()
class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  bool _onlyOpen = false;

  Future<void> _open(Invoice invoice) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(l10n.invoiceFetching)));
    try {
      final pdf = await ref.read(apiProvider).invoicePdf(invoice.id);
      final path = await openPdf(pdf, '${invoice.number}.pdf');
      messenger.hideCurrentSnackBar();
      if (path != null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.invoiceSavedTo(path))));
      }
      // Deliberately broad: a plugin that cannot do something on this platform throws an
      // Error, not an Exception, and then nothing visibly happened.
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  Future<void> _mail(Invoice invoice) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final message = await ref.read(apiProvider).mailInvoice(invoice.id);
      messenger.showSnackBar(SnackBar(content: Text(message ?? l10n.actionDone)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The open invoices are always fetched: in the "All" list they decide which invoice
    // is still outstanding, and they fill the summary at the top.
    final open = ref.watch(invoicesProvider(false));
    // Under the "Still to be paid" filter too, the chart draws all invoices.
    final all = ref.watch(invoicesProvider(true));
    final shown = _onlyOpen ? open : all;
    final openIds = {for (final i in open.value ?? const <Invoice>[]) i.id};

    Future<void> refresh() async {
      ref.invalidate(invoicesProvider);
      await ref.read(invoicesProvider(_onlyOpen ? false : true).future);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreInvoices),
        actions: [RefreshAction(onRefresh: refresh)],
      ),
      body: Refreshable(
        onRefresh: refresh,
        // A single scrolling list: summary, chart and filter scroll up along with it, so
        // that on a phone the invoices themselves get the screen.
        child: ResponsiveListView(
          maxWidth: 720,
          children: [
            _Summary(open: open),
            if (all.value case final invoices?) InvoiceChart(invoices: invoices, openIds: openIds),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l10n.invoiceFilterAll)),
                    ButtonSegment(value: true, label: Text(l10n.invoiceFilterOpen)),
                  ],
                  selected: {_onlyOpen},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _onlyOpen = s.single),
                ),
              ),
            ),
            AsyncView(
              value: shown,
              placeholder: placeholderInvoices,
              onRetry: () => ref.invalidate(invoicesProvider),
              builder: (invoices) => invoices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(_onlyOpen ? l10n.invoicesNoneOpen : l10n.listEmpty),
                      ),
                    )
                  : _InvoiceList(
                      invoices: invoices,
                      openIds: openIds,
                      onOpen: _open,
                      onMail: _mail,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.open});

  final AsyncValue<List<Invoice>> open;

  @override
  Widget build(BuildContext context) {
    final invoices = open.value;
    if (invoices == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final clear = invoices.isEmpty;
    final total = invoices.fold<double>(0, (sum, i) => sum + (i.amountValue ?? 0));

    return Card(
      color: clear ? scheme.primaryContainer : scheme.errorContainer,
      child: ListTile(
        leading: Icon(
          clear ? Icons.check_circle_outline : Icons.error_outline,
          color: clear ? scheme.onPrimaryContainer : scheme.onErrorContainer,
        ),
        title: Text(
          clear ? l10n.invoicesNoneOpen : l10n.invoicesOpenTotal(invoices.length),
          style: TextStyle(color: clear ? scheme.onPrimaryContainer : scheme.onErrorContainer),
        ),
        trailing: clear || total == 0
            ? null
            : Text(
                NumberFormat.simpleCurrency(locale: locale, name: 'EUR').format(total),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: scheme.onErrorContainer),
              ),
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({
    required this.invoices,
    required this.openIds,
    required this.onOpen,
    required this.onMail,
  });

  final List<Invoice> invoices;
  final Set<int> openIds;
  final void Function(Invoice) onOpen;
  final void Function(Invoice) onMail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // The location is only information when there is more than one.
    final showLocation = {for (final i in invoices) i.location}.length > 1;
    final narrow = MediaQuery.sizeOf(context).width < 480;

    final children = <Widget>[];
    int? year;
    for (final invoice in invoices) {
      if (invoice.year != year) {
        year = invoice.year;
        if (year != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
              child: Text('$year', style: theme.textTheme.titleSmall),
            ),
          );
        }
      }
      final isOpen = openIds.contains(invoice.id);
      children.add(
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onOpen(invoice),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isOpen
                        ? scheme.errorContainer
                        : scheme.surfaceContainerHighest,
                    foregroundColor: isOpen ? scheme.onErrorContainer : scheme.onSurfaceVariant,
                    child: Icon(isOpen ? Icons.hourglass_bottom : Icons.receipt_long_outlined),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(invoice.date ?? '', style: theme.textTheme.titleMedium),
                        Text(
                          [invoice.number, if (showLocation) invoice.location].nonNulls.join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(invoice.amount ?? '', style: theme.textTheme.titleMedium),
                      Text(
                        isOpen ? l10n.invoiceStatusOpen : invoice.status ?? l10n.invoiceStatusPaid,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isOpen ? scheme.error : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // On a narrow screen a single menu button; two icons squeeze out the text.
                  if (narrow)
                    PopupMenuButton<void Function(Invoice)>(
                      onSelected: (action) => action(invoice),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: onOpen, child: Text(l10n.invoiceOpen)),
                        PopupMenuItem(value: onMail, child: Text(l10n.invoiceMail)),
                      ],
                    )
                  else ...[
                    IconButton(
                      tooltip: l10n.invoiceMail,
                      icon: const Icon(Icons.forward_to_inbox_outlined),
                      onPressed: () => onMail(invoice),
                    ),
                    IconButton(
                      tooltip: l10n.invoiceOpen,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      onPressed: () => onOpen(invoice),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    // No ListView of its own: the rows live in the screen's scrolling list.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
