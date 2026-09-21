import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:managevity/l10n/l10n.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/providers/services.dart';
import 'package:managevity/providers/sync_provider.dart';
import 'package:managevity/services/calendar/sync_engine.dart';

import '../fixtures/fixtures.dart';

/// [child] in a ProviderScope + MaterialApp with the English locale, on fake services.
/// Signed in by default, with location "Downtown".
Widget testApp(
  Widget child, {
  required FakeSportivityApi api,
  FakeCredentialStore? credentials,
  FakeSettingsService? settings,
}) {
  final store = credentials ?? FakeCredentialStore(session: const Session(token: 'fake'));
  api.session ??= store.session;
  return ProviderScope(
    overrides: [
      apiProvider.overrideWithValue(api),
      credentialStoreProvider.overrideWithValue(store),
      settingsServiceProvider.overrideWithValue(settings ?? FakeSettingsService()),
      cacheServiceProvider.overrideWithValue(FakeCacheService()),
      syncIndexStoreProvider.overrideWithValue(MemorySyncIndexStore()),
      syncLockProvider.overrideWithValue(noSyncLock),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: ThemeData(useMaterial3: true),
      home: child,
    ),
  );
}
