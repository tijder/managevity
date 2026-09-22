import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../utils/errors.dart';
import '../models/sync_settings.dart';
import '../providers/lessons_provider.dart';
import '../providers/services.dart';
import '../providers/sync_provider.dart';
import '../services/calendar/calendar_sync_target.dart';
import '../services/credential_store.dart';
import '../widgets/async_view.dart';
import '../widgets/responsive.dart';

@RoutePage()
class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  // On web our own origin is the server: the proxy in the image serves /remote.php/dav/.
  final _url = TextEditingController(text: kIsWeb ? Uri.base.origin : '');
  final _username = TextEditingController();
  final _password = TextEditingController();

  SyncTargetKind? _picking;
  List<CalendarInfo>? _calendars;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(credentialStoreProvider).readCalDav().then((c) {
      if (c == null || !mounted) return;
      _url.text = c.baseUrl;
      _username.text = c.username;
      _password.text = c.password;
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // Catch broadly: an error that silently vanishes here leaves behind a button that
      // seems to do nothing.
    } catch (e) {
      if (mounted) setState(() => _error = describeError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _findCalendars(SyncTargetKind kind) => _guard(() async {
    final sync = ref.read(syncProvider.notifier);
    if (kind == SyncTargetKind.calDav) {
      await sync.saveCalDav(
        CalDavCredentials(
          baseUrl: _url.text.trim(),
          username: _username.text.trim(),
          password: _password.text,
        ),
      );
    }
    final calendars = await sync.listCalendars(kind);
    if (mounted) setState(() => _calendars = calendars);
  });

  Future<void> _choose(SyncTargetKind kind, CalendarInfo? calendar) => _guard(() async {
    await ref.read(syncProvider.notifier).choose(kind, calendar: calendar);
    if (mounted) {
      setState(() {
        _picking = null;
        _calendars = null;
      });
    }
    if (calendar != null) await _syncNow();
  });

  Future<void> _syncNow() => _guard(() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Fetched fresh, never the offline copy: the calendar only follows a list that the
    // server has just confirmed.
    final result = await ref.read(bookedLessonsProvider.notifier).refreshAndSync();
    if (result != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.syncResult(result.created, result.updated, result.deleted))),
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moreSync)),
      body: AsyncView(
        value: ref.watch(syncProvider),
        onRetry: () => ref.invalidate(syncProvider),
        builder: (settings) {
          final kind = _picking ?? settings.kind;
          return ResponsiveListView(
            maxWidth: 640,
            padding: 16,
            children: [
              Text(l10n.syncExplain),
              const SizedBox(height: 16),
              Text(l10n.syncTarget, style: Theme.of(context).textTheme.titleMedium),
              RadioGroup<SyncTargetKind>(
                groupValue: kind,
                onChanged: (value) {
                  if (value == null) return;
                  if (value == SyncTargetKind.off) {
                    _choose(SyncTargetKind.off, null);
                    return;
                  }
                  setState(() {
                    _picking = value;
                    _calendars = null;
                    _error = null;
                  });
                  if (value == SyncTargetKind.deviceCalendar) _findCalendars(value);
                },
                child: Column(
                  children: [
                    RadioListTile(value: SyncTargetKind.off, title: Text(l10n.syncOff)),
                    if (deviceCalendarSupported)
                      RadioListTile(
                        value: SyncTargetKind.deviceCalendar,
                        title: Text(l10n.syncDevice),
                        subtitle: Text(l10n.syncDeviceHint),
                      ),
                    RadioListTile(
                      value: SyncTargetKind.calDav,
                      title: Text(l10n.syncCalDav),
                      subtitle: Text(kIsWeb ? l10n.syncWebNeedsProxy : l10n.syncCalDavHint),
                    ),
                  ],
                ),
              ),
              if (_picking == SyncTargetKind.calDav) ...[
                const SizedBox(height: 8),
                if (!kIsWeb)
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.syncServerUrl,
                      hintText: l10n.syncServerUrlHint,
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  decoration: InputDecoration(labelText: l10n.syncUsername),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.syncAppPassword,
                    helperText: l10n.syncAppPasswordHint,
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _findCalendars(SyncTargetKind.calDav),
                  child: Text(l10n.syncFindCalendars),
                ),
              ],
              if (_busy)
                const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (_calendars != null && _picking != null) ...[
                const SizedBox(height: 8),
                Text(l10n.syncChooseCalendar, style: Theme.of(context).textTheme.titleMedium),
                if (_calendars!.isEmpty) Text(l10n.syncNoCalendars),
                for (final calendar in _calendars!)
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(calendar.name),
                    onTap: _busy ? null : () => _choose(_picking!, calendar),
                  ),
              ],
              if (settings.enabled && _picking == null) ...[
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text(settings.calendarName ?? settings.calendarId!),
                  subtitle: Text(l10n.syncCurrent),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(
                    settings.lastRun == null
                        ? l10n.syncNever
                        : DateFormat.yMMMd(locale).add_Hm().format(settings.lastRun!),
                  ),
                  subtitle: Text(l10n.syncLastRun),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(l10n.syncReminder),
                  trailing: DropdownButton<int?>(
                    value: settings.reminderMinutes,
                    onChanged: _busy
                        ? null
                        : (minutes) async {
                            await ref.read(syncProvider.notifier).setReminder(minutes);
                            await _syncNow();
                          },
                    items: [
                      DropdownMenuItem(value: null, child: Text(l10n.syncReminderNone)),
                      for (final minutes in const [15, 30, 60, 120])
                        DropdownMenuItem(
                          value: minutes,
                          child: Text(l10n.syncReminderMinutes(minutes)),
                        ),
                    ],
                  ),
                ),
                if (settings.lastError != null)
                  Text(
                    settings.lastError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _syncNow,
                  icon: const Icon(Icons.sync),
                  label: Text(l10n.syncNow),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
