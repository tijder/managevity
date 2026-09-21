import 'package:flutter_riverpod/flutter_riverpod.dart';

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
