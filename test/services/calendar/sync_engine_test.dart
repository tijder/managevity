import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/services/calendar/calendar_sync_target.dart';
import 'package:managevity/services/calendar/sync_engine.dart';
import 'package:managevity/utils/errors.dart';

class FakeCalendarTarget implements CalendarSyncTarget {
  /// ref → event. Also holds events the engine did not write.
  final events = <String, CalendarEvent>{};
  final failOn = <String>{};
  var _seq = 0;

  @override
  Future<List<CalendarInfo>> listCalendars() async => const [
    CalendarInfo(id: 'cal', name: 'Sport'),
  ];

  @override
  Future<WrittenEvent> upsert(
    String calendarId,
    CalendarEvent event, {
    WrittenEvent? existing,
  }) async {
    if (failOn.contains(event.uid)) {
      throw const CalendarSyncException(AppError.calendarFailed, statusCode: 500);
    }
    final ref = existing?.ref ?? 'ref-${_seq++}';
    events[ref] = event;
    return WrittenEvent(ref: ref, etag: 'etag-${_seq++}');
  }

  @override
  Future<void> delete(String calendarId, WrittenEvent existing) async {
    events.remove(existing.ref);
  }
}

class _Stopped extends Error {}

class _StoppedAfterFirst extends FakeCalendarTarget {
  var _writes = 0;

  @override
  Future<WrittenEvent> upsert(String calendarId, CalendarEvent event, {WrittenEvent? existing}) {
    if (_writes++ > 0) throw _Stopped();
    return super.upsert(calendarId, event, existing: existing);
  }
}

CalendarEvent lesson(int id, DateTime start, {String title = 'Yoga', bool tentative = false}) =>
    CalendarEvent(
      uid: lessonUid(id),
      title: title,
      startUtc: start,
      endUtc: start.add(const Duration(hours: 1)),
      tentative: tentative,
    );

void main() {
  final now = DateTime.utc(2026, 9, 21, 12);
  final tomorrow = now.add(const Duration(days: 1));
  late FakeCalendarTarget target;
  late MemorySyncIndexStore store;
  late SyncEngine engine;

  setUp(() {
    target = FakeCalendarTarget();
    store = MemorySyncIndexStore();
    engine = SyncEngine(target: target, store: store, clock: () => now);
  });

  Future<SyncResult> run(Map<int, CalendarEvent> booked) =>
      engine.sync(calendarId: 'cal', booked: booked, windowStart: now);

  test('a new lesson is created, a second run does nothing', () async {
    final first = await run({1: lesson(1, tomorrow)});
    expect((first.created, first.updated, first.deleted), (1, 0, 0));
    expect(target.events, hasLength(1));

    final second = await run({1: lesson(1, tomorrow)});
    expect((second.created, second.unchanged), (0, 1));
  });

  test('a changed lesson is updated on the same ref', () async {
    await run({1: lesson(1, tomorrow)});
    final ref = target.events.keys.single;

    final result = await run({1: lesson(1, tomorrow, title: 'Yoga (room 2)')});
    expect(result.updated, 1);
    expect(target.events.keys.single, ref);
    expect(target.events[ref]!.title, 'Yoga (room 2)');
  });

  test('waiting list → confirmed counts as a change', () async {
    await run({1: lesson(1, tomorrow, tentative: true)});
    final result = await run({1: lesson(1, tomorrow)});
    expect(result.updated, 1);
    expect(target.events.values.single.tentative, isFalse);
  });

  test('a cancelled lesson is removed', () async {
    await run({1: lesson(1, tomorrow), 2: lesson(2, tomorrow)});
    final result = await run({2: lesson(2, tomorrow)});
    expect(result.deleted, 1);
    expect(target.events.values.single.uid, lessonUid(2));
  });

  test('events the engine did not write stay untouched', () async {
    target.events['own'] = lesson(99, tomorrow, title: 'Dentist');
    await run({1: lesson(1, tomorrow)});
    await run({});
    expect(target.events.keys, ['own']);
  });

  test('a lesson that is over stays in the calendar', () async {
    final yesterday = now.subtract(const Duration(days: 1));
    // Written while it still fell inside the window.
    await engine.sync(
      calendarId: 'cal',
      booked: {1: lesson(1, yesterday)},
      windowStart: yesterday.subtract(const Duration(hours: 1)),
    );
    final result = await run({});
    expect(result.deleted, 0);
    expect(target.events, hasLength(1));
  });

  test('old index entries are forgotten without removing the event', () async {
    final longAgo = now.subtract(const Duration(days: 45));
    await engine.sync(calendarId: 'cal', booked: {1: lesson(1, longAgo)}, windowStart: longAgo);
    await run({});
    expect(await store.load('cal'), isEmpty);
    expect(target.events, hasLength(1));
  });

  test('an error on one lesson does not hold up the rest and is retried later', () async {
    target.failOn.add(lessonUid(1));
    final first = await run({1: lesson(1, tomorrow), 2: lesson(2, tomorrow)});
    expect(first.created, 1);
    expect(first.errors, hasLength(1));
    expect(first.ok, isFalse);

    target.failOn.clear();
    final second = await run({1: lesson(1, tomorrow), 2: lesson(2, tomorrow)});
    expect((second.created, second.unchanged), (1, 1));
  });

  test(
    'the index is saved after every write, so a sync cut off halfway leaves no orphans',
    () async {
      // The second write never returns: the operating system stopped the background task.
      final stopped = _StoppedAfterFirst();
      engine = SyncEngine(target: stopped, store: store, clock: () => now);
      expect(() => run({1: lesson(1, tomorrow), 2: lesson(2, tomorrow)}), throwsA(isA<_Stopped>()));
      await pumpEventQueue();
      expect((await store.load('cal')).keys, [1]);

      // The next run knows lesson 1 and only writes lesson 2.
      engine = SyncEngine(target: target, store: store, clock: () => now);
      final result = await run({1: lesson(1, tomorrow), 2: lesson(2, tomorrow)});
      expect((result.created, result.unchanged), (1, 1));
    },
  );

  test('the index is per calendar: another calendar starts empty', () async {
    await run({1: lesson(1, tomorrow)});
    final other = await engine.sync(
      calendarId: 'other',
      booked: {1: lesson(1, tomorrow)},
      windowStart: now,
    );
    expect(other.created, 1);
    expect(target.events, hasLength(2));
  });

  test("removeAll removes only the engine's own events", () async {
    target.events['own'] = lesson(99, tomorrow, title: 'Dentist');
    await run({1: lesson(1, tomorrow), 2: lesson(2, tomorrow)});
    final result = await engine.removeAll('cal');
    expect(result.deleted, 2);
    expect(target.events.keys, ['own']);
    expect(await store.load('cal'), isEmpty);
  });
}
