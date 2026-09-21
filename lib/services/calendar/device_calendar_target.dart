import 'package:device_calendar_plus/device_calendar_plus.dart';

import '../../utils/errors.dart';
import 'calendar_sync_target.dart';

/// Writes to a calendar on the device (Android). Whether that calendar then goes on to
/// Nextcloud is up to the device itself (e.g. DAVx⁵).
class DeviceCalendarTarget implements CalendarSyncTarget {
  DeviceCalendarTarget({DeviceCalendar? plugin}) : _plugin = plugin ?? DeviceCalendar.instance;

  final DeviceCalendar _plugin;

  /// An event's id is a row number in Android's calendar storage. After restoring app data
  /// on another phone, or after that storage has been wiped, a stored id can point at one of
  /// the user's own events. That is why every event of ours carries this marker, and nothing
  /// that lacks it is ever modified or deleted.
  static const _marker = 'Managevity · ';
  static String markerFor(String uid) => '$_marker$uid';

  /// Only true if [ref] exists, lives in [calendarId] and carries our marker — for exactly
  /// this lesson if [uid] is known (updating), otherwise for any lesson at all (deleting).
  Future<bool> _isOurs(String ref, String calendarId, [String? uid]) async {
    final event = await _plugin.getEvent(ref);
    return event != null &&
        event.calendarId == calendarId &&
        (event.description ?? '').contains(uid == null ? _marker : markerFor(uid));
  }

  String _describe(CalendarEvent event) => [
    if (event.description != null && event.description!.isNotEmpty) event.description!,
    markerFor(event.uid),
  ].join('\n\n');

  Future<void> _ensurePermission() async {
    final status = await _plugin.requestPermissions();
    if (status != CalendarPermissionStatus.granted) {
      throw const CalendarSyncException(AppError.calendarPermission);
    }
  }

  @override
  Future<List<CalendarInfo>> listCalendars() async {
    await _ensurePermission();
    final calendars = await _plugin.listCalendars();
    return [
      for (final c in calendars)
        if (!c.readOnly && !c.hidden)
          CalendarInfo(
            id: c.id,
            name: c.accountName == null || c.accountName == c.name
                ? c.name
                : '${c.name} (${c.accountName})',
            color: c.colorHex,
          ),
    ];
  }

  @override
  Future<WrittenEvent> upsert(
    String calendarId,
    CalendarEvent event, {
    WrittenEvent? existing,
  }) async {
    await _ensurePermission();
    final availability = event.tentative ? EventAvailability.tentative : EventAvailability.busy;

    // Not ours (any more): hands off, and create a new event.
    if (existing != null && await _isOurs(existing.ref, calendarId, event.uid)) {
      try {
        await _plugin.updateEvent(
          eventId: existing.ref,
          title: event.title,
          startDate: event.startUtc.toLocal(),
          endDate: event.endUtc.toLocal(),
          location: _patch(event.location),
          description: Patch.set(_describe(event)),
          availability: availability,
          reminders: event.reminder == null ? const Patch.clear() : Patch.set([event.reminder!]),
        );
        return WrittenEvent(ref: existing.ref);
      } on DeviceCalendarException catch (e) {
        // Deleted in the calendar app: create it again, the lesson is the source of truth.
        if (e.errorCode != DeviceCalendarError.notFound) rethrow;
      }
    }

    final id = await _plugin.createEvent(
      calendarId: calendarId,
      title: event.title,
      startDate: event.startUtc.toLocal(),
      endDate: event.endUtc.toLocal(),
      location: event.location,
      description: _describe(event),
      availability: availability,
      reminders: event.reminder == null ? null : [event.reminder!],
    );
    return WrittenEvent(ref: id);
  }

  @override
  Future<void> delete(String calendarId, WrittenEvent existing) async {
    await _ensurePermission();
    // Gone, moved or not ours: do nothing. Better a lesson that lingers than one of the
    // user's own events disappearing.
    if (!await _isOurs(existing.ref, calendarId)) return;
    try {
      await _plugin.deleteEvent(eventId: existing.ref);
    } on DeviceCalendarException catch (e) {
      if (e.errorCode != DeviceCalendarError.notFound) rethrow;
    }
  }

  Patch<String> _patch(String? value) =>
      value == null || value.isEmpty ? const Patch.clear() : Patch.set(value);
}
