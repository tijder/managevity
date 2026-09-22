// Renders every screen with made-up data, at phone and desktop size, so the design can
// be judged without starting the app.
//
//   flutter test --tags golden --update-goldens test/screenshots/screenshots_test.dart
//
// Output goes to doc/screenshots/ (gitignored). Excluded in CI: see dart_test.yaml.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/l10n/l10n.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/models/sync_settings.dart';
import 'package:managevity/providers/services.dart';
import 'package:managevity/providers/sync_provider.dart';
import 'package:managevity/router/app_router.dart';
import 'package:managevity/services/calendar/sync_engine.dart';
import 'package:managevity/theme.dart';

import '../fixtures/fixtures.dart';
import 'demo_api.dart';

Future<void> _loadFonts() async {
  final fonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async =>
      ByteData.view(File('$fonts/$name').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(read(f));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

// 'phone-dark' renders the same screens in the dark theme.
const _sizes = {'phone': Size(400, 860), 'desktop': Size(1400, 900), 'phone-dark': Size(400, 860)};

const _pages = {
  'schedule': '/',
  'my-lessons': '/mine',
  'busy': '/busy',
  'more': '/more',
  'lesson': '/lesson/6',
  'lesson-booked': '/lesson/2',
  'invoices': '/invoices',
  'memberships': '/memberships',
  'profile': '/profile',
  'guests': '/guests',
  'offers': '/offers',
  'news': '/news',
  'rules': '/info?rules=true',
  'favourites': '/favourites',
  'sync': '/sync',
  'location': '/location',
  'about': '/about',
};

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('en');
  });

  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final MapEntry(key: name, value: path) in {..._pages, 'login': '/login'}.entries) {
      // Only with --update-goldens: the images contain today's date, so comparing with an
      // earlier run makes no sense and would turn `flutter test` red.
      testWidgets('$name ($sizeName)', skip: !autoUpdateGoldenFiles, (tester) async {
        // Tests draw shadows as black borders by default; here we want the real picture.
        debugDisableShadows = false;
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final brightness = sizeName.endsWith('dark') ? Brightness.dark : Brightness.light;
        final loggedIn = name != 'login';
        final api = DemoApi();
        final store = FakeCredentialStore(session: loggedIn ? const Session(token: 'demo') : null);
        api.session = store.session;
        final settings = FakeSettingsService()
          ..sync = SyncSettings(
            kind: SyncTargetKind.calDav,
            calendarId: 'cal',
            calendarName: 'Sport',
            reminderMinutes: 30,
            lastRun: DateTime(2026, 9, 21, 14, 5),
          );
        final container = ProviderContainer(
          overrides: [
            apiProvider.overrideWithValue(api),
            credentialStoreProvider.overrideWithValue(store),
            settingsServiceProvider.overrideWithValue(settings),
            cacheServiceProvider.overrideWithValue(FakeCacheService()),
            syncIndexStoreProvider.overrideWithValue(MemorySyncIndexStore()),
            syncTargetFactoryProvider.overrideWithValue((_) async => null),
            syncLockProvider.overrideWithValue(noSyncLock),
          ],
        );
        final router = AppRouter(container);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              theme: buildTheme(
                brightness,
              ).copyWith(textTheme: buildTheme(brightness).textTheme.apply(fontFamily: 'Roboto')),
              routerConfig: router.config(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (path != '/' && loggedIn) {
          if (const ['/mine', '/busy', '/more'].contains(path)) {
            router.navigatePath(path);
          } else {
            router.pushPath(path);
          }
          await tester.pumpAndSettle();
        }

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../doc/screenshots/$sizeName-$name.png'),
        );
        // Reset before the end of the test: the framework checks this before the
        // tearDowns run.
        debugDisableShadows = true;
        // Dispose the container here as well: the week schedule keeps a timer, and the
        // framework counts pending timers before the tearDowns run.
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      });
    }
  }
}
