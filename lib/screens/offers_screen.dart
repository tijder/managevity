import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/membership_offer.dart';
import '../providers/content_providers.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../utils/errors.dart';
import '../utils/pdf_opener.dart';
import '../widgets/async_view.dart';
import '../widgets/refreshable.dart';
import '../widgets/responsive.dart';

/// The gym's memberships, or with [upgradeFrom] what that membership can switch to. Only to
/// look at: taking one out needs a signature and a bank account, and goes through the gym.
@RoutePage()
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key, @QueryParam('upgradeFrom') this.upgradeFrom});

  final int? upgradeFrom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final provider = offersProvider((language: language, upgradeFrom: upgradeFrom));
    Future<void> refresh() => ref.refresh(provider.future);

    return Scaffold(
      appBar: AppBar(
        title: Text(upgradeFrom == null ? l10n.moreOffers : l10n.offersSwitchTitle),
        actions: [RefreshAction(onRefresh: refresh)],
      ),
      body: Refreshable(
        onRefresh: refresh,
        child: AsyncView(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          builder: (offers) => ResponsiveListView(
            maxWidth: 720,
            children: [
              if (offers.isEmpty) EmptyView(l10n.listEmpty),
              for (final offer in offers) _OfferCard(offer: offer, language: language),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.offerViaGym, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.language});

  final MembershipOffer offer;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        title: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(offer.description),
            if (offer.promotion)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.offerPromotion,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          [
            offer.amount,
            if (offer.paymentMethod != null) l10n.offerPaymentMethod(offer.paymentMethod!),
          ].nonNulls.join(' · '),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        // Fetched only when opened: three calls per offer, and there can be many offers.
        children: [
          if (offer.promotionInfo case final info? when info.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(info)),
          _OfferDetails(offer: offer, language: language),
        ],
      ),
    );
  }
}

class _OfferDetails extends ConsumerWidget {
  const _OfferDetails({required this.offer, required this.language});

  final MembershipOffer offer;
  final String language;

  Future<void> _openPdf(BuildContext context, WidgetRef ref, OfferCondition condition) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdf = await ref
          .read(apiProvider)
          .conditionPdf(ref.read(locationIdProvider), language, condition.type);
      final path = await openPdf(pdf, '${condition.type}.pdf');
      if (path != null) messenger.showSnackBar(SnackBar(content: Text(l10n.invoiceSavedTo(path))));
      // Broad on purpose, as for invoices: a platform plugin throws an Error, not an Exception.
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final details = ref.watch(
      offerDetailsProvider((language: language, id: offer.id, promotion: offer.promotion)),
    );
    return switch (details) {
      AsyncData(value: (:final costs, :final conditions, :final addons)) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.offerStartToday, style: theme.textTheme.titleSmall),
          if (costs.description != null || costs.firstCosts != null)
            _AmountRow(costs.description ?? '', costs.firstCosts ?? ''),
          for (final d in costs.deposits) _AmountRow(d.description, d.amount),
          if (costs.total != null) _AmountRow(l10n.offerTotal, costs.total!, bold: true),
          if (addons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l10n.membershipAddons, style: theme.textTheme.titleSmall),
            for (final a in addons) _AmountRow(a.description, a.price ?? ''),
          ],
          if (conditions.conditions.isNotEmpty || conditions.ibanRequired) ...[
            const SizedBox(height: 12),
            Text(l10n.offerConditions, style: theme.textTheme.titleSmall),
            if (conditions.ibanRequired) Text(l10n.offerIbanRequired),
            for (final c in conditions.conditions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  [
                    c.linkText?.replaceAll('*', '').trim() ?? c.text,
                    if (c.mandatory) '(${l10n.offerRequired})',
                  ].join(' '),
                ),
                trailing: c.hasPdf ? const Icon(Icons.picture_as_pdf_outlined) : null,
                onTap: c.hasPdf ? () => _openPdf(context, ref, c) : null,
              ),
          ],
        ],
      ),
      AsyncError(:final error) => Text(describeError(l10n, error)),
      _ => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.amount, {this.bold = false});

  final String label;
  final String amount;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 16),
          Text(amount, style: style),
        ],
      ),
    );
  }
}
