import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/l10n/l10n.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/models/sync_settings.dart';
import 'package:managevity/providers/lessons_provider.dart';
import 'package:managevity/providers/services.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/providers/sync_provider.dart';
import 'package:managevity/screens/sync_settings_screen.dart';
import 'package:managevity/services/calendar/sync_engine.dart';
import 'package:managevity/services/calendar/calendar_sync_target.dart';
import 'package:managevity/utils/errors.dart';

import '../fixtures/fixtures.dart';
import '../services/calendar/sync_engine_test.dart' show FakeCalendarTarget;

class _RefusingTarget extends FakeCalendarTarget {
  @override
  Future<List<CalendarInfo>> listCalendars() async =>
      throw const CalendarSyncException(AppError.calendarAuth, statusCode: 401);
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final tomorrow = dayOf(DateTime.now()).add(const Duration(days: 1, hours: 19));

  Future<(FakeSettingsService, FakeCredentialStore)> pump(
    WidgetTester tester,
    CalendarSyncTarget target,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    )..session = const Session(token: 'fake');
    final settings = FakeSettingsService();
    final store = FakeCredentialStore(session: api.session);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          credentialStoreProvider.overrideWithValue(store),
          settingsServiceProvider.overrideWithValue(settings),
          cacheServiceProvider.overrideWithValue(FakeCacheService()),
          syncIndexStoreProvider.overrideWithValue(MemorySyncIndexStore()),
          syncTargetFactoryProvider.overrideWithValue((_) async => target),
          syncLockProvider.overrideWithValue(noSyncLock),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          // In the app the router makes sure the session is loaded before this screen appears.
          home: _WithSession(child: SyncSettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (settings, store);
  }

  testWidgets('setting up CalDAV: store the credentials, choose a calendar, sync right away', (
    tester,
  ) async {
    final target = FakeCalendarTarget();
    final (settings, store) = await pump(tester, target);

    await tester.tap(find.text('CalDAV (Nextcloud)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Server URL'),
      'https://cloud.example.org',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'test');
    await tester.enterText(find.widgetWithText(TextField, 'App password'), 'secret');
    await tester.tap(find.text('Find calendars'));
    await tester.pumpAndSettle();

    expect(store.calDav?.baseUrl, 'https://cloud.example.org');
    await tester.tap(find.text('Sport'));
    await tester.pumpAndSettle();

    expect(settings.sync.kind, SyncTargetKind.calDav);
    expect(settings.sync.calendarId, 'cal');
    // The booked lesson is in there right away.
    expect(target.events.values.single.uid, lessonUid(5));
    expect(find.text('Current calendar'), findsOneWidget);
  });

  testWidgets('a rejected password gives a message in plain language', (tester) async {
    await pump(tester, _RefusingTarget());
    await tester.tap(find.text('CalDAV (Nextcloud)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find calendars'));
    await tester.pumpAndSettle();
    expect(find.text('The calendar server rejects the credentials.'), findsOneWidget);
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
