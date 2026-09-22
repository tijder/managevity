import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/guest_pass.dart';
import '../providers/content_providers.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../utils/errors.dart';
import '../widgets/async_view.dart';
import '../widgets/confirm_action.dart';
import '../widgets/refreshable.dart';
import '../widgets/responsive.dart';

/// "Samen sporten": the guests you bring along, and signing up a new one.
@RoutePage()
class GuestsScreen extends ConsumerStatefulWidget {
  const GuestsScreen({super.key});

  @override
  ConsumerState<GuestsScreen> createState() => _GuestsScreenState();
}

class _GuestsScreenState extends ConsumerState<GuestsScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    ref
      ..invalidate(guestAllowanceProvider)
      ..invalidate(guestPassesProvider);
    await ref.read(guestPassesProvider.future);
  }

  /// Runs [action] and shows what the server said, or why it failed.
  Future<void> _run(Future<String?> Function() action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final message = await action();
      messenger.showSnackBar(SnackBar(content: Text(message ?? l10n.actionDone)));
      ref.invalidate(guestPassesProvider);
      ref.invalidate(guestAllowanceProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final guest = await showDialog<NewGuest>(context: context, builder: (_) => const _GuestForm());
    if (guest == null || !mounted) return;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final ok = await confirmAction(
      context,
      title: l10n.guestAdd,
      lines: [l10n.guestAddConfirm(guest.name, DateFormat.yMMMEd(locale).format(guest.visitDate))],
      confirmLabel: l10n.guestAdd,
    );
    if (!ok) return;
    await _run(() => ref.read(apiProvider).addGuest(ref.read(locationIdProvider), guest));
  }

  Future<void> _remove(GuestPass guest) async {
    final l10n = context.l10n;
    final ok = await confirmAction(
      context,
      title: l10n.guestRemove,
      lines: [l10n.guestRemoveConfirm(guest.name)],
      confirmLabel: l10n.guestRemove,
    );
    if (!ok) return;
    await _run(() => ref.read(apiProvider).deleteGuest(ref.read(locationIdProvider), guest));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final allowance = ref.watch(guestAllowanceProvider).value;
    // Unknown (still loading, or the check failed) is not a no: the server decides anyway.
    final allowed = allowance?.allowed ?? true;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreGuests),
        actions: [RefreshAction(onRefresh: _refresh)],
      ),
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.guestAdd),
            )
          : null,
      body: Refreshable(
        onRefresh: _refresh,
        child: AsyncView(
          value: ref.watch(guestPassesProvider),
          onRetry: () => ref.invalidate(guestPassesProvider),
          builder: (guests) => ResponsiveListView(
            maxWidth: 640,
            children: [
              if (!allowed)
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(allowance?.message ?? l10n.guestsNotAllowed),
                  ),
                ),
              if (guests.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l10n.guestsEmpty)),
                ),
              for (final guest in guests)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                    title: Text(guest.name),
                    subtitle: Text(
                      [
                        if (guest.visitDate != null)
                          DateFormat.yMMMEd(locale).format(guest.visitDate!),
                        if (guest.used) l10n.guestVisited,
                        guest.email,
                      ].nonNulls.join(' · '),
                    ),
                    trailing: guest.used
                        ? null
                        : IconButton(
                            tooltip: l10n.guestRemove,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: _busy ? null : () => _remove(guest),
                          ),
                  ),
                ),
              // Room for the button, so it never covers the last guest.
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestForm extends StatefulWidget {
  const _GuestForm();

  @override
  State<_GuestForm> createState() => _GuestFormState();
}

class _GuestFormState extends State<_GuestForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  late DateTime _date = DateUtils.dateOnly(DateTime.now());
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = context.l10n.guestNameRequired);
      return;
    }
    Navigator.pop(
      context,
      NewGuest(
        name: name,
        email: _email.text.trim(),
        mobile: _mobile.text.trim(),
        visitDate: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return AlertDialog(
      title: Text(l10n.guestAdd),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l10n.guestName, errorText: _nameError),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.guestEmail),
            ),
            TextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l10n.guestMobile),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.guestDate),
              subtitle: Text(DateFormat.yMMMEd(locale).format(_date)),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.back)),
        FilledButton(onPressed: _submit, child: Text(l10n.guestAdd)),
      ],
    );
  }
}
