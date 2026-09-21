import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location.dart';
import '../services/credential_store.dart';
import 'services.dart';

class SessionState {
  const SessionState({this.loggedIn = false, this.location, this.demo = false});

  final bool loggedIn;

  /// Signed in to the in-app demo server rather than a real gym.
  final bool demo;
  final Location? location;

  bool get ready => loggedIn && location != null;
}

class SessionNotifier extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final api = ref.watch(apiProvider);
    final store = ref.watch(credentialStoreProvider);
    final settings = ref.watch(settingsServiceProvider);

    // Expired token: silently log in again with the stored credentials.
    api.onSessionExpired = () async {
      final login = await store.readLogin();
      if (login == null) {
        state = const AsyncData(SessionState());
        return null;
      }
      try {
        final fresh = await api.login(login.user, login.password);
        await store.writeSession(fresh);
        return fresh;
      } on Exception {
        state = const AsyncData(SessionState());
        return null;
      }
    };

    final session = await store.readSession();
    if (session == null) return const SessionState();
    api.session = session;
    final saved = await settings.getLocation();
    return SessionState(
      loggedIn: true,
      demo: api.isDemo,
      location: saved == null ? null : Location(id: saved.$1, name: saved.$2),
    );
  }

  /// Throws a SportivityException carrying the server's message if it fails.
  Future<void> login(String user, String password, {required bool remember}) async {
    final api = ref.read(apiProvider);
    final store = ref.read(credentialStoreProvider);
    final session = await api.login(user, password);
    await store.writeSession(session);
    if (remember) await store.writeLogin(SportivityCredentials(user, password));
    // A location that is still saved (an expired session, not a sign-out) is picked up
    // again, so signing back in does not ask for it a second time.
    final saved = await ref.read(settingsServiceProvider).getLocation();
    state = AsyncData(
      SessionState(
        loggedIn: true,
        demo: api.isDemo,
        location:
            state.value?.location ??
            (saved == null ? null : Location(id: saved.$1, name: saved.$2)),
      ),
    );
  }

  Future<void> chooseLocation(Location location) async {
    await ref.read(settingsServiceProvider).setLocation(location.id, location.name);
    state = AsyncData(
      SessionState(loggedIn: true, demo: ref.read(apiProvider).isDemo, location: location),
    );
  }

  Future<void> logout() async {
    ref.read(apiProvider).session = null;
    await ref.read(credentialStoreProvider).clearLogin();
    await ref.read(settingsServiceProvider).clearLocation();
    await ref.read(cacheServiceProvider).clear();
    state = const AsyncData(SessionState());
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

/// The URL a visitor asked for before they were sent to sign in. Read once, then forgotten.
class PendingPath extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String path) => state = path;

  String? take() {
    final path = state;
    state = null;
    return path;
  }
}

final pendingPathProvider = NotifierProvider<PendingPath, String?>(PendingPath.new);

/// The chosen location; throws if there is none — screens behind the guard may rely on it.
final locationIdProvider = Provider<int>((ref) {
  final location = ref.watch(sessionProvider).value?.location;
  if (location == null) throw StateError('No location chosen');
  return location.id;
});

final locationsProvider = FutureProvider.autoDispose<List<Location>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.locations();
});
