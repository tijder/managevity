import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';
import 'session_storage.dart';

class SportivityCredentials {
  const SportivityCredentials(this.user, this.password);
  final String user;
  final String password;
}

class CalDavCredentials {
  const CalDavCredentials({required this.baseUrl, required this.username, required this.password});
  final String baseUrl;
  final String username;
  final String password;
}

/// Everything that is secret, in the platform's keychain (Keystore, libsecret).
///
/// The web has no keychain — there it would end up in localStorage. Passwords are
/// therefore never stored on web. Only the session token is, in sessionStorage: that
/// survives a page reload and disappears with the tab.
abstract interface class CredentialStore {
  Future<SportivityCredentials?> readLogin();
  Future<void> writeLogin(SportivityCredentials credentials);
  Future<Session?> readSession();
  Future<void> writeSession(Session session);
  Future<CalDavCredentials?> readCalDav();
  Future<void> writeCalDav(CalDavCredentials credentials);
  Future<void> clearCalDav();

  /// Logging out: login and session are removed. The CalDAV credentials stay.
  Future<void> clearLogin();
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final _memory = <String, String>{};

  static const _keyLogin = 'login_v1';
  static const _keySession = 'session_v1';
  static const _keyCalDav = 'caldav_v1';

  Future<Map<String, dynamic>?> _read(String key) async {
    final raw = kIsWeb
        ? (key == _keySession ? readSessionStorage(key) : _memory[key])
        : await _storage.read(key: key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  }

  Future<void> _write(String key, Map<String, Object?> value) async {
    final raw = jsonEncode(value);
    if (kIsWeb) {
      key == _keySession ? writeSessionStorage(key, raw) : _memory[key] = raw;
    } else {
      await _storage.write(key: key, value: raw);
    }
  }

  Future<void> _delete(String key) async {
    _memory.remove(key);
    if (kIsWeb) {
      removeSessionStorage(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  @override
  Future<SportivityCredentials?> readLogin() async {
    final json = await _read(_keyLogin);
    if (json == null) return null;
    return SportivityCredentials(json['user'] as String, json['password'] as String);
  }

  @override
  Future<void> writeLogin(SportivityCredentials c) =>
      _write(_keyLogin, {'user': c.user, 'password': c.password});

  @override
  Future<Session?> readSession() async {
    final json = await _read(_keySession);
    return json == null ? null : Session.tryFromJson(json);
  }

  @override
  Future<void> writeSession(Session session) => _write(_keySession, session.toJson());

  @override
  Future<CalDavCredentials?> readCalDav() async {
    final json = await _read(_keyCalDav);
    if (json == null) return null;
    return CalDavCredentials(
      baseUrl: json['baseUrl'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
    );
  }

  @override
  Future<void> writeCalDav(CalDavCredentials c) =>
      _write(_keyCalDav, {'baseUrl': c.baseUrl, 'username': c.username, 'password': c.password});

  @override
  Future<void> clearCalDav() => _delete(_keyCalDav);

  @override
  Future<void> clearLogin() async {
    await _delete(_keyLogin);
    await _delete(_keySession);
  }
}
