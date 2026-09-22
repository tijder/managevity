import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/payment.dart';
import '../providers/content_providers.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../widgets/confirm_action.dart';
import '../widgets/payment_page.dart';
import '../widgets/async_view.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';
import '../widgets/refreshable.dart';

/// Read-only: changing, freezing and cancelling are deliberately not part of this app.
@RoutePage()
class MembershipsScreen extends ConsumerWidget {
  const MembershipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale);
    final addons = ref.watch(addonsProvider).value ?? const [];

    Future<void> refresh() async {
      ref.invalidate(addonsProvider);
      ref.invalidate(membershipsProvider);
      await ref.read(membershipsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreMemberships),
        actions: [RefreshAction(onRefresh: refresh)],
      ),
      body: Refreshable(
        onRefresh: refresh,
        child: AsyncView(
          value: ref.watch(membershipsProvider),
          placeholder: placeholderMemberships,
          onRetry: () => ref.invalidate(membershipsProvider),
          builder: (memberships) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            return ResponsiveListView(
              children: [
                const _BalanceCard(),
                if (memberships.isEmpty) Center(child: Text(l10n.listEmpty)),
                for (final m in memberships)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(m.description, style: theme.textTheme.titleLarge),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: m.active
                                      ? scheme.primaryContainer
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  m.active ? l10n.membershipActive : l10n.membershipInactive,
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // On a wide screen two columns, otherwise stacked.
                          CardGrid(
                            minTileWidth: 300,
                            maxColumns: 2,
                            children: [
                              if (m.locationName != null)
                                InfoRow(
                                  icon: Icons.place_outlined,
                                  label: l10n.membershipLocation,
                                  value: m.locationName!,
                                ),
                              if (m.amount != null)
                                InfoRow(
                                  icon: Icons.payments_outlined,
                                  label: l10n.membershipPrice,
                                  value: m.amount!,
                                ),
                              if (m.contractEndDate != null)
                                InfoRow(
                                  icon: Icons.event_outlined,
                                  label: l10n.membershipUntil,
                                  value: date.format(m.contractEndDate!),
                                ),
                              InfoRow(
                                icon: Icons.login,
                                label: l10n.membershipVisitsLeft,
                                value: m.unlimitedVisits
                                    ? l10n.membershipUnlimited
                                    : '${m.visitsLeft ?? '–'}',
                              ),
                              InfoRow(
                                icon: Icons.event_available_outlined,
                                label: l10n.membershipCreditsLeft,
                                value: m.unlimitedReservations
                                    ? l10n.membershipUnlimited
                                    : '${m.reservationCreditsLeft ?? '–'}',
                              ),
                            ],
                          ),
                          if (m.blockageText != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(m.blockageText!, style: TextStyle(color: scheme.error)),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (addons.isNotEmpty) ...[
                  SectionTitle(l10n.membershipAddons),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final (i, a) in addons.indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          ListTile(
                            title: Text(a.description),
                            subtitle: Text([a.membershipName, a.price].nonNulls.join(' · ')),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: a.on
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                a.on ? l10n.addonOn : l10n.addonOff,
                                style: theme.textTheme.labelLarge,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.membershipReadOnly, style: theme.textTheme.bodySmall),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The credit, with topping up when the gym offers amounts for it.
class _BalanceCard extends ConsumerStatefulWidget {
  const _BalanceCard();

  @override
  ConsumerState<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<_BalanceCard> with RefreshAfterPayment {
  @override
  void onReturn() => ref.invalidate(userContentProvider);

  Future<void> _topUp(List<CreditOption> options, {required bool sportCredits}) async {
    final l10n = context.l10n;
    final option = await showDialog<CreditOption>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.balanceTopUpChoose),
        children: [
          for (final o in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, o),
              child: ListTile(
                title: Text(o.label),
                subtitle: o.info == null ? null : Text(o.info!),
              ),
            ),
        ],
      ),
    );
    if (option == null || !mounted) return;
    final ok = await confirmAction(
      context,
      title: l10n.balanceTopUp,
      lines: [l10n.balanceTopUpConfirm(option.label), l10n.paymentInBrowser],
      confirmLabel: l10n.paymentToPage,
    );
    if (!ok || !mounted) return;
    final opened = await openPaymentPage(
      context,
      ref,
      () => ref
          .read(apiProvider)
          .creditLink(ref.read(locationIdProvider), option.amount, sportCredits: sportCredits),
    );
    if (opened) paymentStarted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final customer = ref.watch(userContentProvider).value?.customer;
    final options = ref.watch(creditOptionsProvider).value ?? const [];
    final balance = customer?.balance;
    if (balance == null && options.isEmpty) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(l10n.balanceTitle),
        subtitle: balance == null
            ? null
            : Text(balance, style: Theme.of(context).textTheme.titleMedium),
        trailing: options.isEmpty
            ? null
            : FilledButton.tonal(
                onPressed: () => _topUp(options, sportCredits: customer?.hasSportsCredits ?? false),
                child: Text(l10n.balanceTopUp),
              ),
      ),
    );
  }
}
