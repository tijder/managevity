import 'dart:convert';

import '../utils/errors.dart';

enum SyncTargetKind { off, deviceCalendar, calDav }

/// Where a sync error came from; decides how it is put into words.
enum SyncErrorSource { api, calendar, unexpected }

/// Why the last sync failed, as data rather than as a sentence: it is written by whichever
/// isolate ran the sync (possibly in the background, with only the system language to go
/// by) and read later on a screen that knows the user's language. `describeSyncError` in
/// `utils/errors.dart` turns it into text.
class SyncError {
  const SyncError({
    this.source = SyncErrorSource.unexpected,
    this.code,
    this.status,
    this.detail,
    this.lesson,
    this.removing = false,
    this.legacyText,
  });

  final SyncErrorSource source;
  final AppError? code;
  final int? status;

  /// What the server said, or a technical detail (a URL); language-neutral.
  final String? detail;

  /// The lesson that could not be written; null when it was not about one lesson.
  final String? lesson;

  /// Removing an event failed (then there is no lesson title to name).
  final bool removing;

  /// A sentence stored by an earlier version of the app; shown as it is.
  final String? legacyText;

  String encode() => jsonEncode({
    'source': source.name,
    'code': code?.name,
    'status': status,
    'detail': detail,
    'lesson': lesson,
    'removing': removing,
  });

  /// Never throws: whatever is in storage that is not ours is an old sentence.
  static SyncError? decode(Object? stored) {
    if (stored is! String || stored.isEmpty) return null;
    try {
      final json = jsonDecode(stored);
      if (json is Map && json['source'] is String) {
        return SyncError(
          source: SyncErrorSource.values.asNameMap()[json['source']] ?? SyncErrorSource.unexpected,
          code: AppError.values.asNameMap()[json['code']],
          status: json['status'] is int ? json['status'] as int : null,
          detail: json['detail'] is String ? json['detail'] as String : null,
          lesson: json['lesson'] is String ? json['lesson'] as String : null,
          removing: json['removing'] == true,
        );
      }
    } on FormatException {
      // Not JSON: a sentence from before errors were stored as data.
    }
    return SyncError(legacyText: stored);
  }
}

class SyncSettings {
  const SyncSettings({
    this.kind = SyncTargetKind.off,
    this.calendarId,
    this.calendarName,
    this.reminderMinutes,
    this.lastRun,
    this.lastError,
    this.leftovers = const [],
  });

  final SyncTargetKind kind;
  final String? calendarId;
  final String? calendarName;

  /// Minutes in advance; null = no reminder.
  final int? reminderMinutes;
  final DateTime? lastRun;
  final SyncError? lastError;

  /// Calendars (as [scopeOf]) the sync was moved away from while its events could not all
  /// be removed: no connection, or the other isolate was writing. They are tried again
  /// after every sync until they are clean, so nothing is left behind that nobody updates.
  final List<String> leftovers;

  bool get enabled => kind != SyncTargetKind.off && calendarId != null;

  static String scopeOf(SyncTargetKind kind, String calendarId) => '${kind.name}:$calendarId';

  /// The other way round; null for something that is not a scope.
  static (SyncTargetKind, String)? parseScope(String scope) {
    final colon = scope.indexOf(':');
    if (colon <= 0) return null;
    final kind = SyncTargetKind.values.asNameMap()[scope.substring(0, colon)];
    return kind == null ? null : (kind, scope.substring(colon + 1));
  }

  /// Identifies the target: a different target or a different calendar is another scope.
  String? get scope => enabled ? scopeOf(kind, calendarId!) : null;

  SyncSettings copyWith({
    DateTime? lastRun,
    SyncError? lastError,
    bool clearError = false,
    int? reminderMinutes,
    bool clearReminder = false,
    List<String>? leftovers,
  }) => SyncSettings(
    kind: kind,
    calendarId: calendarId,
    calendarName: calendarName,
    reminderMinutes: clearReminder ? null : reminderMinutes ?? this.reminderMinutes,
    lastRun: lastRun ?? this.lastRun,
    lastError: clearError ? null : lastError ?? this.lastError,
    leftovers: leftovers ?? this.leftovers,
  );
}
