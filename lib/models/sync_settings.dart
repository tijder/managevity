enum SyncTargetKind { off, deviceCalendar, calDav }

class SyncSettings {
  const SyncSettings({
    this.kind = SyncTargetKind.off,
    this.calendarId,
    this.calendarName,
    this.reminderMinutes,
    this.lastRun,
    this.lastError,
  });

  final SyncTargetKind kind;
  final String? calendarId;
  final String? calendarName;

  /// Minutes in advance; null = no reminder.
  final int? reminderMinutes;
  final DateTime? lastRun;
  final String? lastError;

  bool get enabled => kind != SyncTargetKind.off && calendarId != null;

  /// Key of the sync index: a different target or a different calendar starts empty.
  String? get scope => enabled ? '${kind.name}:$calendarId' : null;

  SyncSettings copyWith({
    DateTime? lastRun,
    String? lastError,
    bool clearError = false,
    int? reminderMinutes,
    bool clearReminder = false,
  }) => SyncSettings(
    kind: kind,
    calendarId: calendarId,
    calendarName: calendarName,
    reminderMinutes: clearReminder ? null : reminderMinutes ?? this.reminderMinutes,
    lastRun: lastRun ?? this.lastRun,
    lastError: clearError ? null : lastError ?? this.lastError,
  );
}
