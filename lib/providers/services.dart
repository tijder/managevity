import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/cache_service.dart';
import '../services/calendar/sync_engine.dart';
import '../services/credential_store.dart';
import '../services/settings_service.dart';
import '../services/sportivity_api.dart';

// The services as providers, so tests can override them with a fake.
final apiProvider = Provider<SportivityApi>((ref) => SportivityApi());
final credentialStoreProvider = Provider<CredentialStore>((ref) => SecureCredentialStore());
final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());
final syncIndexStoreProvider = Provider<SyncIndexStore>((ref) => HiveSyncIndexStore());

/// Opens a page outside the app (the gym's payment page). A provider so tests can see what
/// would have been opened instead of opening it.
typedef OpenExternal = Future<bool> Function(Uri uri);
final openExternalProvider = Provider<OpenExternal>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
