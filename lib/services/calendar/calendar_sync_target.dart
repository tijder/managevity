import '../../utils/errors.dart';

/// A calendar the sync can write to.
class CalendarInfo {
  const CalendarInfo({required this.id, required this.name, this.color});

  /// CalDAV: the absolute collection URL. Device calendar: the platform's id.
  final String id;
  final String name;
  final String? color;
}

/// What ends up in the calendar for a booked lesson. Deliberately separate from the API
/// model, so that the sync can be tested without the API and so that the hash only changes
/// when the calendar would notice the difference.
class CalendarEvent {
  const CalendarEvent({
    required this.uid,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    this.location,
    this.description,
    this.tentative = false,
    this.categories = const [],
    this.geo,
    this.reminder,
  });

  final String uid;
  final String title;
  final DateTime startUtc;
  final DateTime endUtc;
  final String? location;
  final String? description;

  /// Waiting list: the spot is not certain yet.
  final bool tentative;

  final List<String> categories;

  /// Latitude and longitude of the location.
  final (double, double)? geo;

  /// How long in advance the calendar should alert; null = no reminder.
  final Duration? reminder;

  /// Changes exactly when the event needs to be written again.
  String get contentHash => [
    title,
    startUtc.toUtc().toIso8601String(),
    endUtc.toUtc().toIso8601String(),
    location ?? '',
    description ?? '',
    tentative,
    categories.join(','),
    geo ?? '',
    reminder?.inMinutes ?? '',
  ].join('\u001f');
}

/// What the target returns after a write; the engine keeps it in its index.
class WrittenEvent {
  const WrittenEvent({required this.ref, this.etag});

  /// CalDAV: the URL of the .ics object. Device calendar: the platform's event id.
  final String ref;
  final String? etag;
}

class CalendarSyncException implements Exception {
  const CalendarSyncException(this.code, {this.statusCode, this.detail});

  final AppError code;
  final int? statusCode;

  /// Technical detail (a URL, an XML error); language-neutral.
  final String? detail;

  @override
  String toString() => 'CalendarSyncException(${code.name}, $statusCode): ${detail ?? ''}';
}

abstract interface class CalendarSyncTarget {
  Future<List<CalendarInfo>> listCalendars();

  /// Writes [event] to [calendarId]. [existing] is what an earlier upsert returned,
  /// or null for a new event.
  Future<WrittenEvent> upsert(String calendarId, CalendarEvent event, {WrittenEvent? existing});

  /// An event that is already gone is not an error.
  Future<void> delete(String calendarId, WrittenEvent existing);
}
