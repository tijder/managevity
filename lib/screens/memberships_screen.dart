import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/membership.dart';
import '../models/payment.dart';
import '../utils/errors.dart';
import '../providers/content_providers.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../widgets/confirm_action.dart';
import '../widgets/payment_page.dart';
import '../widgets/async_view.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';
import '../widgets/refreshable.dart';

/// Memberships, credit and add-ons. Freezing, cancelling, withdrawing, switching add-ons
/// and topping up are offered only where the server allows them, and always ask first.
/// Taking out or converting a membership is not here: that goes through the gym.
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
                          _MembershipActions(membership: m),
                        ],
                      ),
                    ),
                  ),
                if (addons.isNotEmpty) ...[
                  SectionTitle(l10n.membershipAddons),
                  _AddonList(addons: addons),
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

/// Add-ons, each with a switch. Switching asks twice: first here (what, from when, for how
/// much), then with the server's own words from `TurnOnOff`, before `TurnOnOffConfirmation`
/// carries it out.
class _AddonList extends ConsumerStatefulWidget {
  const _AddonList({required this.addons});

  final List<Addon> addons;

  @override
  ConsumerState<_AddonList> createState() => _AddonListState();
}

class _AddonListState extends ConsumerState<_AddonList> {
  int? _busy;

  Future<void> _switch(Addon addon, bool on) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = DateUtils.dateOnly(DateTime.now());
    final from = await showDatePicker(
      context: context,
      helpText: l10n.addonFrom,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (from == null || !mounted) return;
    final date = DateFormat.yMMMd(locale).format(from);
    final title = on ? l10n.addonTurnOn : l10n.addonTurnOff;
    final asked = await confirmAction(
      context,
      title: title,
      lines: [
        on
            ? l10n.addonConfirmOn(addon.description, date)
            : l10n.addonConfirmOff(addon.description, date),
        if (addon.price != null) l10n.addonPrice(addon.price!),
      ],
      confirmLabel: l10n.next,
    );
    if (!asked || !mounted) return;

    setState(() => _busy = addon.id);
    final api = ref.read(apiProvider);
    try {
      final terms = await api.requestAddonChange(addon, on: on, from: from);
      if (!mounted) return;
      final confirmed = await confirmAction(
        context,
        title: title,
        lines: [l10n.addonServerSays, terms ?? l10n.addonPrice(addon.price ?? '–')],
        confirmLabel: l10n.confirm,
      );
      if (!confirmed) return;
      final message = await api.confirmAddonChange(addon, on: on, from: from);
      messenger.showSnackBar(SnackBar(content: Text(message ?? l10n.actionDone)));
      ref.invalidate(addonsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, a) in widget.addons.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16),
            ListTile(
              title: Text(a.description),
              subtitle: Text([a.membershipName, a.price].nonNulls.join(' · ')),
              trailing: a.mandatory
                  ? Text(l10n.addonMandatory, style: theme.textTheme.labelLarge)
                  : Switch(value: a.on, onChanged: _busy != null ? null : (on) => _switch(a, on)),
            ),
          ],
        ],
      ),
    );
  }
}

enum _Change { freeze, cancel, withdraw }

/// What the user filled in for a change.
typedef _ChangeRequest = ({
  DateTime from,
  DateTime? until,
  String? note,
  CancellationReason? reason,
});

/// Freeze, cancel and withdraw, each only when the server allows it for this membership.
class _MembershipActions extends ConsumerStatefulWidget {
  const _MembershipActions({required this.membership});

  final Membership membership;

  @override
  ConsumerState<_MembershipActions> createState() => _MembershipActionsState();
}

class _MembershipActionsState extends ConsumerState<_MembershipActions> {
  bool _busy = false;

  Future<void> _start(_Change change) async {
    final m = widget.membership;
    final request = await showDialog<_ChangeRequest>(
      context: context,
      builder: (_) => _ChangeForm(change: change, membership: m),
    );
    if (request == null || !mounted) return;
    final l10n = context.l10n;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    final reason = request.reason?.description ?? request.note;
    final ok = await confirmAction(
      context,
      title: switch (change) {
        _Change.freeze => l10n.membershipFreeze,
        _Change.cancel => l10n.membershipCancel,
        _Change.withdraw => l10n.membershipWithdraw,
      },
      lines: [
        switch (change) {
          _Change.freeze => l10n.freezeConfirm(
            m.description,
            date.format(request.from),
            date.format(request.until!),
          ),
          _Change.cancel => l10n.cancelConfirm(m.description, date.format(request.from)),
          _Change.withdraw => l10n.withdrawConfirm(m.description),
        },
        if (reason != null && reason.isNotEmpty) l10n.changeReasonLine(reason),
        l10n.changeIsRequest,
      ],
      confirmLabel: l10n.changeSend,
      // A freeze ends by itself; a cancellation or withdrawal cannot be taken back here.
      irreversible: change != _Change.freeze,
    );
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(apiProvider);
    setState(() => _busy = true);
    try {
      final message = await switch (change) {
        _Change.freeze => api.freezeMembership(
          m,
          reason: request.note ?? '',
          from: request.from,
          until: request.until!,
        ),
        _Change.cancel => api.cancelMembership(m, from: request.from, reason: request.reason!),
        _Change.withdraw => api.withdrawMembership(m, from: request.from, reason: request.reason!),
      };
      messenger.showSnackBar(SnackBar(content: Text(message ?? l10n.actionDone)));
      ref.invalidate(membershipsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final m = widget.membership;
    if (m.terminated) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(l10n.membershipTerminated, style: Theme.of(context).textTheme.labelLarge),
      );
    }
    final actions = [
      if (m.allowFreeze) (_Change.freeze, l10n.membershipFreeze, Icons.ac_unit),
      if (m.allowCancel) (_Change.cancel, l10n.membershipCancel, Icons.event_busy_outlined),
      if (m.coolingOff) (_Change.withdraw, l10n.membershipWithdraw, Icons.undo),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (change, label, icon) in actions)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _start(change),
              icon: Icon(icon),
              label: Text(label),
            ),
        ],
      ),
    );
  }
}

class _ChangeForm extends ConsumerStatefulWidget {
  const _ChangeForm({required this.change, required this.membership});

  final _Change change;
  final Membership membership;

  @override
  ConsumerState<_ChangeForm> createState() => _ChangeFormState();
}

class _ChangeFormState extends ConsumerState<_ChangeForm> {
  final _note = TextEditingController();
  late DateTime _from;
  late DateTime _until;
  CancellationReason? _reason;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    final end = widget.membership.contractEndDate;
    // Cancelling: by default at the end of the contract, the usual moment.
    _from = widget.change == _Change.cancel && end != null && end.isAfter(today)
        ? DateUtils.dateOnly(end)
        : today;
    _until = DateTime(_from.year, _from.month + 1, _from.day);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial, DateTime first) {
    final today = DateUtils.dateOnly(DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(today.year + 3, today.month, today.day),
    );
  }

  void _submit() {
    final needsReason = widget.change != _Change.freeze;
    if (needsReason && _reason == null) {
      setState(() => _error = context.l10n.changeReasonRequired);
      return;
    }
    Navigator.pop<_ChangeRequest>(context, (
      from: _from,
      until: widget.change == _Change.freeze ? _until : null,
      note: _note.text.trim(),
      reason: _reason,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    final today = DateUtils.dateOnly(DateTime.now());
    final change = widget.change;
    final reasons = ref.watch(cancellationReasonsProvider);

    Widget dateTile(String label, DateTime value, DateTime first, void Function(DateTime) set) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: Text(label),
          subtitle: Text(date.format(value)),
          onTap: () async {
            final picked = await _pick(value, first);
            if (picked != null) setState(() => set(picked));
          },
        );

    return AlertDialog(
      title: Text(switch (change) {
        _Change.freeze => l10n.membershipFreeze,
        _Change.cancel => l10n.membershipCancel,
        _Change.withdraw => l10n.membershipWithdraw,
      }),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.membership.description, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (change == _Change.freeze)
              TextField(
                controller: _note,
                decoration: InputDecoration(labelText: l10n.changeReason),
              )
            else
              switch (reasons) {
                AsyncData(:final value) => DropdownButtonFormField<CancellationReason>(
                  initialValue: _reason,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.changeReason, errorText: _error),
                  items: [
                    for (final r in value) DropdownMenuItem(value: r, child: Text(r.description)),
                  ],
                  onChanged: (r) => setState(() {
                    _reason = r;
                    _error = null;
                  }),
                ),
                AsyncError(:final error) => Text(describeError(l10n, error)),
                _ => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
            // The right of withdrawal applies now; there is no date to choose.
            if (change != _Change.withdraw)
              dateTile(l10n.changeFrom, _from, today, (d) {
                _from = d;
                if (!_until.isAfter(d)) _until = DateTime(d.year, d.month + 1, d.day);
              }),
            if (change == _Change.freeze)
              dateTile(l10n.changeUntil, _until, _from, (d) => _until = d),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.back)),
        FilledButton(onPressed: _submit, child: Text(l10n.next)),
      ],
    );
  }
}
