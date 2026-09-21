import '../models/sync_settings.dart';
import 'storage.dart';

class SettingsService {
  static const _boxName = 'settings_v1';
  static const _keyLocationId = 'locationId';
  static const _keyLocationName = 'locationName';
  static const _keySyncKind = 'syncKind';
  static const _keySyncCalendarId = 'syncCalendarId';
  static const _keySyncCalendarName = 'syncCalendarName';
  static const _keySyncReminder = 'syncReminderMinutes';
  static const _keySyncLastRun = 'syncLastRun';
  static const _keySyncLastError = 'syncLastError';

  Future<IsolatedBox<dynamic>> _openBox() => openStorageBox(_boxName);

  Future<(int, String)?> getLocation() async {
    final box = await _openBox();
    final id = await box.get(_keyLocationId) as int?;
    if (id == null) return null;
    return (id, await box.get(_keyLocationName, defaultValue: '$id') as String);
  }

  Future<void> setLocation(int id, String name) async {
    final box = await _openBox();
    await box.put(_keyLocationId, id);
    await box.put(_keyLocationName, name);
  }

  Future<void> clearLocation() async {
    final box = await _openBox();
    await box.deleteAll([_keyLocationId, _keyLocationName]);
  }

  Future<SyncSettings> getSync() async {
    final box = await _openBox();
    final lastRun = await box.get(_keySyncLastRun) as String?;
    return SyncSettings(
      kind: SyncTargetKind.values.asNameMap()[await box.get(_keySyncKind)] ?? SyncTargetKind.off,
      calendarId: await box.get(_keySyncCalendarId) as String?,
      calendarName: await box.get(_keySyncCalendarName) as String?,
      reminderMinutes: await box.get(_keySyncReminder) as int?,
      lastRun: lastRun == null ? null : DateTime.tryParse(lastRun),
      lastError: await box.get(_keySyncLastError) as String?,
    );
  }

  Future<void> setSync(SyncSettings settings) async {
    final box = await _openBox();
    await box.putAll({
      _keySyncKind: settings.kind.name,
      _keySyncCalendarId: settings.calendarId,
      _keySyncCalendarName: settings.calendarName,
      _keySyncReminder: settings.reminderMinutes,
      _keySyncLastRun: settings.lastRun?.toIso8601String(),
      _keySyncLastError: settings.lastError,
    });
  }
}
