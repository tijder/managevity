import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/l10n/l10n.dart';
import 'package:managevity/models/gym_extras.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/providers/lessons_provider.dart';
import 'package:managevity/providers/services.dart';
import 'package:managevity/providers/sync_provider.dart';
import 'package:managevity/router/app_router.dart';
import 'package:managevity/screens/about_screen.dart';
import 'package:managevity/screens/guests_screen.dart';
import 'package:managevity/screens/invoices_screen.dart';
import 'package:managevity/screens/lesson_detail_screen.dart';
import 'package:managevity/screens/location_screen.dart';
import 'package:managevity/screens/login_screen.dart';
import 'package:managevity/screens/my_lessons_screen.dart';
import 'package:managevity/services/calendar/sync_engine.dart';

import 'fixtures/fixtures.dart';

// The whole app with its real router: what happens when someone opens a URL directly.
void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final tomorrow = dayOf(DateTime.now()).add(const Duration(days: 1, hours: 19));

  Future<AppRouter> pumpApp(
    WidgetTester tester, {
    required String url,
    bool loggedIn = true,
    bool hasLocation = true,
    List<GymButton> buttons = const [],
    List<Uri>? opened,
  }) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, description: 'Judo', start: tomorrow)],
    )..buttonList = buttons;
    final store = FakeCredentialStore(session: loggedIn ? const Session(token: 'fake') : null);
    api.session = store.session;
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        apiProvider.overrideWithValue(api),
        credentialStoreProvider.overrideWithValue(store),
        settingsServiceProvider.overrideWithValue(
          FakeSettingsService(location: hasLocation ? (7, 'Downtown') : null),
        ),
        cacheServiceProvider.overrideWithValue(FakeCacheService()),
        syncIndexStoreProvider.overrideWithValue(MemorySyncIndexStore()),
        syncTargetFactoryProvider.overrideWithValue((_) async => null),
        syncLockProvider.overrideWithValue(noSyncLock),
        openExternalProvider.overrideWithValue((uri) async {
          opened?.add(uri);
          return true;
        }),
      ],
    );
    final router = AppRouter(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router.config(
            includePrefixMatches: true,
            deepLinkBuilder: (_) => DeepLink.path(url, includePrefixMatches: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Tidy up inside the test body: the schedule keeps a timer, and the framework counts
    // pending timers before tear-downs run.
    addTearDown(() {});
    _cleanup = () async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    };
    return router;
  }

  testWidgets('signed in: a lesson URL opens that lesson, with the main screen under it', (
    tester,
  ) async {
    final router = await pumpApp(tester, url: '/lesson/5');
    expect(find.byType(LessonDetailScreen), findsOneWidget);
    expect(find.text('Judo'), findsWidgets);
    expect(router.canPop(), isTrue, reason: 'there must be something to go back to');
    await _cleanup();
  });

  testWidgets('signed in: a tab and a settings page each have their own URL', (tester) async {
    await pumpApp(tester, url: '/mine');
    expect(find.byType(MyLessonsScreen), findsOneWidget);
    await _cleanup();

    await pumpApp(tester, url: '/invoices');
    expect(find.byType(InvoicesScreen), findsOneWidget);
    await _cleanup();

    await pumpApp(tester, url: '/guests');
    expect(find.byType(GuestsScreen), findsOneWidget);
    await _cleanup();

    await pumpApp(tester, url: '/offers?upgradeFrom=1');
    expect(find.text('Switch membership'), findsOneWidget);
    await _cleanup();
  });

  testWidgets("the gym's own links are in More, and open outside the app", (tester) async {
    final opened = <Uri>[];
    final link = Uri.parse('https://example.org/timetable');
    await pumpApp(
      tester,
      url: '/more',
      buttons: [GymButton(label: 'Timetable', uri: link)],
      opened: opened,
    );
    await tester.tap(find.text('Timetable'));
    await tester.pumpAndSettle();
    expect(opened, [link]);
    await _cleanup();
  });

  testWidgets('signed out: the link leads to sign-in first, and to the lesson right after', (
    tester,
  ) async {
    await pumpApp(tester, url: '/lesson/5', loggedIn: false);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(LessonDetailScreen), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, 'robin@example.org');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(LessonDetailScreen), findsOneWidget);
    await _cleanup();
  });

  testWidgets('signed in but no location yet: choose one, then on to the requested page', (
    tester,
  ) async {
    await pumpApp(tester, url: '/invoices', hasLocation: false);
    expect(find.byType(LocationScreen), findsOneWidget);

    await tester.tap(find.text('Downtown'));
    await tester.pumpAndSettle();
    expect(find.byType(InvoicesScreen), findsOneWidget);
    await _cleanup();
  });

  testWidgets('the about page is public and says what sets the app apart', (tester) async {
    await pumpApp(tester, url: '/about', loggedIn: false);
    expect(find.byType(AboutScreen), findsOneWidget);
    for (final text in ['Also on your computer', 'Privacy friendly', 'Syncs to your calendar']) {
      await tester.scrollUntilVisible(find.text(text), 300);
      expect(find.text(text), findsOneWidget);
    }
    // Further down the page than fits on screen.
    await tester.scrollUntilVisible(find.text('Open the demo'), 300);
    expect(find.text('Open the demo'), findsOneWidget);
    await _cleanup();
  });

  testWidgets('the sign-in screen links to the about page', (tester) async {
    await pumpApp(tester, url: '/', loggedIn: false);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.ensureVisible(find.text('About this app'));
    await tester.tap(find.text('About this app'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    await _cleanup();
  });
}

Future<void> Function() _cleanup = () async {};
