import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/services/calendar/calendar_sync_target.dart';
import 'package:managevity/services/calendar/device_calendar_target.dart';

/// The device calendar, which also holds the user's own events.
class FakeDeviceCalendar implements DeviceCalendar {
  final events = <String, ({String calendarId, String title, String? description})>{};
  var _nextId = 100;

  @override
  Future<CalendarPermissionStatus> requestPermissions({
    CalendarAccessLevel level = CalendarAccessLevel.full,
  }) async => CalendarPermissionStatus.granted;

  @override
  Future<Event?> getEvent(String id) async {
    final e = events[id];
    if (e == null) return null;
    return Event(
      eventId: id,
      instanceId: id,
      calendarId: e.calendarId,
      title: e.title,
      description: e.description,
      startDate: DateTime(2026),
      endDate: DateTime(2026),
      isAllDay: false,
      availability: EventAvailability.busy,
      status: EventStatus.confirmed,
      isRecurring: false,
    );
  }

  @override
  Future<String> createEvent({
    String? calendarId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    bool isAllDay = false,
    String? description,
    String? location,
    String? url,
    String? timeZone,
    EventAvailability availability = EventAvailability.busy,
    RecurrenceRule? recurrenceRule,
    List<Duration>? reminders,
  }) async {
    final id = '${_nextId++}';
    events[id] = (calendarId: calendarId!, title: title, description: description);
    return id;
  }

  @override
  Future<void> updateEvent({
    required String eventId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    Patch<String>? description,
    Patch<String>? location,
    Patch<String>? url,
    bool? isAllDay,
    String? timeZone,
    EventAvailability? availability,
    Patch<List<Duration>>? reminders,
  }) async {
    final old = events[eventId]!;
    events[eventId] = (
      calendarId: old.calendarId,
      title: title ?? old.title,
      description: switch (description) {
        PatchSet(:final value) => value,
        PatchClear() => null,
        null => old.description,
      },
    );
  }

  @override
  Future<void> deleteEvent({required String eventId}) async => events.remove(eventId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeDeviceCalendar calendar;
  late DeviceCalendarTarget target;

  final lesson = CalendarEvent(
    uid: 'lesson-1@managevity.g4d.nl',
    title: 'Yoga',
    startUtc: DateTime.utc(2026, 9, 22, 18),
    endUtc: DateTime.utc(2026, 9, 22, 19),
    description: 'Anna',
  );

  setUp(() {
    calendar = FakeDeviceCalendar();
    target = DeviceCalendarTarget(plugin: calendar);
    // An event of the user's own, at the id an old index points to.
    calendar.events['42'] = (calendarId: 'cal', title: 'Dentist', description: 'do not forget');
  });

  test('writing and updating an event of our own happens on the same id', () async {
    final written = await target.upsert('cal', lesson);
    expect(calendar.events[written.ref]!.description, 'Anna\n\nManagevity · ${lesson.uid}');

    final again = await target.upsert(
      'cal',
      CalendarEvent(
        uid: lesson.uid,
        title: 'Yoga (room 2)',
        startUtc: lesson.startUtc,
        endUtc: lesson.endUtc,
      ),
      existing: written,
    );
    expect(again.ref, written.ref);
    expect(calendar.events[written.ref]!.title, 'Yoga (room 2)');
    expect(calendar.events, hasLength(2));
  });

  test("an id that points to one of the user's events is not overwritten", () async {
    final written = await target.upsert('cal', lesson, existing: const WrittenEvent(ref: '42'));
    expect(calendar.events['42']!.title, 'Dentist');
    expect(calendar.events['42']!.description, 'do not forget');
    expect(written.ref, isNot('42'));
  });

  test('…and not deleted either', () async {
    await target.delete('cal', const WrittenEvent(ref: '42'));
    expect(calendar.events['42']!.title, 'Dentist');
  });

  test('the marker of a different lesson is not enough to overwrite', () async {
    final other = await target.upsert('cal', lesson);
    final second = await target.upsert(
      'cal',
      CalendarEvent(
        uid: 'lesson-2@managevity.g4d.nl',
        title: 'Spinning',
        startUtc: lesson.startUtc,
        endUtc: lesson.endUtc,
      ),
      existing: other,
    );
    expect(second.ref, isNot(other.ref));
    expect(calendar.events[other.ref]!.title, 'Yoga');
  });

  test('an event in another calendar stays', () async {
    final written = await target.upsert('cal', lesson);
    await target.delete('other-calendar', written);
    expect(calendar.events.containsKey(written.ref), isTrue);
  });

  test('deleting our own event works, and one that is already gone gives no error', () async {
    final written = await target.upsert('cal', lesson);
    await target.delete('cal', written);
    expect(calendar.events.containsKey(written.ref), isFalse);
    await target.delete('cal', written);
  });
}
