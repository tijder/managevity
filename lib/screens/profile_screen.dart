import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../utils/errors.dart';
import '../models/customer.dart';
import '../providers/content_providers.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../models/profile_settings.dart';
import '../widgets/async_view.dart';
import '../widgets/photo_editor.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';

@RoutePage()
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.moreProfile)),
    body: AsyncView(
      value: ref.watch(userContentProvider),
      placeholder: placeholderUserContent,
      onRetry: () => ref.invalidate(userContentProvider),
      builder: (content) => _ProfileForm(customer: content.customer),
    ),
  );
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.customer});
  final Customer customer;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _address = TextEditingController(text: widget.customer.address);
  late final _houseNumber = TextEditingController(text: widget.customer.houseNumber);
  late final _addition = TextEditingController(text: widget.customer.addition);
  late final _zip = TextEditingController(text: widget.customer.zipCode);
  late final _city = TextEditingController(text: widget.customer.city);
  late final _phone = TextEditingController(text: widget.customer.phone);
  late final _mobile = TextEditingController(text: widget.customer.phoneMobile);
  bool _busy = false;

  List<TextEditingController> get _all => [
    _address,
    _houseNumber,
    _addition,
    _zip,
    _city,
    _phone,
    _mobile,
  ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(apiProvider)
          .setContactDetails(
            ContactDetails(
              address: _address.text.trim(),
              houseNumber: int.tryParse(_houseNumber.text.trim()),
              addition: _addition.text.trim(),
              zipCode: _zip.text.trim(),
              city: _city.text.trim(),
              phone: _phone.text.trim(),
              phoneMobile: _mobile.text.trim(),
            ),
          );
      ref.invalidate(userContentProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Street and city from the postcode and house number, as the gym's own app does.
  Future<void> _lookup() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final number = int.tryParse(_houseNumber.text.trim());
    final zip = _zip.text.trim();
    if (number == null || zip.isEmpty) return;
    setState(() => _busy = true);
    try {
      final found = await ref
          .read(apiProvider)
          .lookupAddress(
            ref.read(locationIdProvider),
            zipCode: zip,
            houseNumber: number,
            addition: _addition.text.trim(),
          );
      if (found == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.profileLookupNotFound)));
      } else {
        _address.text = found.street;
        _city.text = found.city;
        if (found.zipCode case final zip? when zip.isNotEmpty) _zip.text = zip;
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = widget.customer;
    // Only where the gym can look addresses up for the customer's country.
    final canLookUp =
        ref
            .watch(countriesProvider)
            .value
            ?.any((country) => country.name == c.country && country.automaticAddress) ??
        false;
    Widget field(TextEditingController controller, String label, {TextInputType? type}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(labelText: label),
      ),
    );

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ResponsiveListView(
      maxWidth: 640,
      padding: 16,
      children: [
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                EditableCustomerAvatar(name: c.fullName),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.fullName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      if (c.email != null)
                        Text(c.email!, style: TextStyle(color: scheme.onPrimaryContainer)),
                      if (c.balance != null)
                        Text(
                          '${l10n.profileBalance}: ${c.balance}',
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (c.membershipExpirationWarning != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(c.membershipExpirationWarning!, style: TextStyle(color: scheme.error)),
          ),
        const SizedBox(height: 24),
        field(_address, l10n.profileAddress),
        Row(
          children: [
            Expanded(
              child: field(_houseNumber, l10n.profileHouseNumber, type: TextInputType.number),
            ),
            const SizedBox(width: 12),
            Expanded(child: field(_addition, l10n.profileAddition)),
          ],
        ),
        field(_zip, l10n.profileZip),
        if (canLookUp)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: _busy ? null : _lookup,
                icon: const Icon(Icons.search),
                label: Text(l10n.profileLookup),
              ),
            ),
          ),
        field(_city, l10n.profileCity),
        field(_phone, l10n.profilePhone, type: TextInputType.phone),
        field(_mobile, l10n.profileMobile, type: TextInputType.phone),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
        SectionTitle(l10n.profileGymTitle),
        _GymSettings(language: c.language),
      ],
    );
  }
}

/// The language the gym writes in, and which channels it may use. Both are harmless and
/// easy to change back, so they apply at once, with "Undo" in the snackbar.
class _GymSettings extends ConsumerStatefulWidget {
  const _GymSettings({required this.language});

  final String? language;

  @override
  ConsumerState<_GymSettings> createState() => _GymSettingsState();
}

class _GymSettingsState extends ConsumerState<_GymSettings> {
  late String? _language = widget.language;
  OptInSettings? _optIn;
  bool _busy = false;

  Future<void> _setLanguage(String code) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final before = _language;
    setState(() {
      _language = code;
      _busy = true;
    });
    try {
      await ref.read(apiProvider).setLanguage(ref.read(locationIdProvider), code);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.profileLanguageSaved(l10n.languageName(code))),
          action: before == null
              ? null
              : SnackBarAction(label: l10n.undo, onPressed: () => _setLanguage(before)),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _language = before);
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setOptIn(OptInSettings before, OptInSettings after, String what, bool on) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _optIn = after;
      _busy = true;
    });
    try {
      await ref.read(apiProvider).setOptIn(ref.read(locationIdProvider), after);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.optInSaved(what, on ? 'on' : 'off')),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => _setOptIn(after, before, what, !on),
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _optIn = before);
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final optIn = _optIn ?? ref.watch(optInProvider).value;
    final languages = [...gymLanguages, ?(gymLanguages.contains(_language) ? null : _language)];

    Widget toggle(String label, bool value, OptInSettings Function(bool) change) => SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: _busy || optIn == null ? null : (on) => _setOptIn(optIn, change(on), label, on),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: InputDecoration(labelText: l10n.profileLanguage),
              items: [
                for (final code in languages)
                  DropdownMenuItem(value: code, child: Text(l10n.languageName(code))),
              ],
              onChanged: _busy
                  ? null
                  : (code) {
                      if (code != null && code != _language) _setLanguage(code);
                    },
            ),
          ),
          if (optIn != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(l10n.optInTitle, style: Theme.of(context).textTheme.labelLarge),
            ),
            toggle(l10n.optInEmail, optIn.email, (on) => optIn.copyWith(email: on)),
            toggle(l10n.optInCalls, optIn.calls, (on) => optIn.copyWith(calls: on)),
            toggle(l10n.optInWhatsapp, optIn.whatsapp, (on) => optIn.copyWith(whatsapp: on)),
          ],
        ],
      ),
    );
  }
}
