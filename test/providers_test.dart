import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/customer.dart';
import 'package:managevity/models/lesson.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/models/sync_settings.dart';
import 'package:managevity/providers/lessons_provider.dart';
import 'package:managevity/providers/services.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/providers/sync_provider.dart';
import 'package:managevity/services/calendar/calendar_sync_target.dart';
import 'package:managevity/services/calendar/sync_engine.dart';
import 'package:managevity/services/sportivity_api.dart';
import 'package:managevity/utils/errors.dart';

import 'fixtures/fixtures.dart';
import 'services/calendar/sync_engine_test.dart' show FakeCalendarTarget;

/// The per-lesson details are an enrichment; if that call fails, the sync must not get stuck.
class _FlakyApi extends FakeSportivityApi {
  _FlakyApi({super.lessons});

  var attempts = 0;

  @override
  Future<Lesson> lesson(int lessonId) async {
    attempts++;
    throw const SportivityException(AppError.server);
  }

  @override
  Future<UserContent> userContent({int? locationId}) async =>
      throw const SportivityException(AppError.server);
}

/// Books fine, but the list fetched right after fails.
class _FailsAfterBookingApi extends FakeSportivityApi {
  _FailsAfterBookingApi({super.lessons});

  var failing = false;

  @override
  Future<BookingResult> joinLesson(int lessonId, int locationId, {bool buy = false}) async {
    final result = await super.joinLesson(lessonId, locationId, buy: buy);
    failing = true;
    return result;
  }

  @override
  Future<List<Lesson>> bookedLessons(int locationId, DateTime from, DateTime to) async {
    if (failing) throw const SportivityException(AppError.network);
    return super.bookedLessons(locationId, from, to);
  }
}

/// A calendar whose writes hang until [release] is called.
class _GatedCalendar extends FakeCalendarTarget {
  var _gate = Completer<void>();
  final started = <int>[];

  void release() {
    _gate.complete();
    _gate = Completer<void>();
  }

  @override
  Future<WrittenEvent> upsert(
    String calendarId,
    CalendarEvent event, {
    WrittenEvent? existing,
  }) async {
    started.add(started.length);
    await _gate.future;
    return super.upsert(calendarId, event, existing: existing);
  }
}

/// A server that returns only the first day of a week range.
class _TruncatingApi extends FakeSportivityApi {
  _TruncatingApi({super.lessons});

  @override
  Future<List<Lesson>> schedule(int locationId, DateTime from, DateTime to) =>
      super.schedule(locationId, from, from.add(const Duration(days: 1)));
}

void main() {
  final tomorrow = dayOf(DateTime.now()).add(const Duration(days: 1, hours: 9));

  ProviderContainer build(
    FakeSportivityApi api, {
    FakeCredentialStore? store,
    FakeSettingsService? settings,
    CalendarSyncTarget? target,
    FakeCacheService? cache,
    SyncLock lock = noSyncLock,
  }) {
    final credentials = store ?? FakeCredentialStore(session: const Session(token: 'fake'));
    api.session = credentials.session;
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        credentialStoreProvider.overrideWithValue(credentials),
        settingsServiceProvider.overrideWithValue(settings ?? FakeSettingsService()),
        cacheServiceProvider.overrideWithValue(cache ?? FakeCacheService()),
        syncIndexStoreProvider.overrideWithValue(MemorySyncIndexStore()),
        syncTargetFactoryProvider.overrideWithValue((_) async => target),
        syncLockProvider.overrideWithValue(lock),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('signing in stores the password only when asked to', () async {
    final store = FakeCredentialStore();
    final container = build(FakeSportivityApi(), store: store);
    await container.read(sessionProvider.future);

    await container.read(sessionProvider.notifier).login('u', 'p', remember: false);
    expect(store.session?.token, 'fake');
    expect(store.login, isNull);

    await container.read(sessionProvider.notifier).login('u', 'p', remember: true);
    expect(store.login?.password, 'p');
  });

  test('a failed login leaves the session untouched', () async {
    final store = FakeCredentialStore();
    final container = build(
      FakeSportivityApi(loginError: const SportivityException(AppError.loginFailed)),
      store: store,
    );
    await container.read(sessionProvider.future);
    await expectLater(
      container.read(sessionProvider.notifier).login('u', 'x', remember: true),
      throwsA(isA<SportivityException>()),
    );
    expect(store.session, isNull);
    expect(store.login, isNull);
    expect(container.read(sessionProvider).value?.loggedIn, isFalse);
  });

  test('booking and cancelling update the calendar right away', () async {
    final api = FakeSportivityApi(lessons: [lessonFixture(id: 5, start: tomorrow)]);
    final target = FakeCalendarTarget();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
    final container = build(api, settings: settings, target: target);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.future);

    final booked = container.read(bookedLessonsProvider.notifier);
    final sync = container.read(syncProvider.notifier);
    await booked.book(api.lessons.single);
    expect(api.joined, [(5, false)]);
    // The answer does not wait for the calendar; the sync follows on its own.
    await sync.idle;
    expect(target.events.values.single.uid, lessonUid(5));
    expect(settings.sync.lastRun, isNotNull);

    await booked.cancel(api.lessons.single);
    await sync.idle;
    expect(target.events, isEmpty);
  });

  test(
    'the calendar event is complete: per-lesson details, address, coordinates, reminder',
    () async {
      final api = FakeSportivityApi(
        lessons: [
          Lesson(
            id: 5,
            description: 'Judo seniors',
            startUtc: tomorrow.toUtc(),
            endUtc: tomorrow.add(const Duration(hours: 1)).toUtc(),
            bookingStatus: const BookingStatus('Booked'),
            locationName: 'Example Sports Centre',
            room: 'Dojo',
            activity: 'Judo',
            trainer: 'Sam the Trainer',
            maximumParticipants: 24,
            additionalInformation:
                '<p>Judo is no clich&eacute;: it is one of the most versatile sports.</p>',
          ),
        ],
      );
      final target = FakeCalendarTarget();
      final settings = FakeSettingsService()
        ..sync = const SyncSettings(
          kind: SyncTargetKind.calDav,
          calendarId: 'cal',
          reminderMinutes: 60,
        );
      final container = build(api, settings: settings, target: target);
      await container.read(sessionProvider.future);
      await container.read(bookedLessonsProvider.notifier).refreshAndSync();

      final event = target.events.values.single;
      expect(event.title, 'Judo seniors');
      expect(event.location, 'Dojo, Example Sports Centre, Station Road 12, 1234 AB Exampleton');
      expect(event.description, contains('Sam the Trainer'));
      expect(event.description, contains('24'));
      expect(
        event.description,
        contains('Judo is no cliché: it is one of the most versatile sports.'),
      );
      expect(event.categories, ['Judo']);
      expect(event.geo, (52.1, 5.2));
      expect(event.reminder, const Duration(hours: 1));
    },
  );

  test('no contact text and no details: the sync simply carries on', () async {
    final api = _FlakyApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    )..contactHtml = null;
    final target = FakeCalendarTarget();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
    final container = build(api, settings: settings, target: target);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.notifier).refreshAndSync();
    expect(target.events.values.single.title, 'Yoga');
    expect(settings.sync.lastError, isNull);
  });

  test('history: only what is over, newest first', () async {
    final today = dayOf(DateTime.now());
    final api = FakeSportivityApi(
      lessons: [
        lessonFixture(id: 1, start: today.subtract(const Duration(days: 30)), status: 'Booked'),
        lessonFixture(id: 2, start: today.subtract(const Duration(days: 2)), status: 'Booked'),
        lessonFixture(id: 3, start: tomorrow, status: 'Booked'),
      ],
    );
    final container = build(api);
    await container.read(sessionProvider.future);
    final history = await container.read(lessonHistoryProvider.future);
    expect(history.map((l) => l.id), [2, 1]);
  });

  test('schedule: first only the chosen day, the week arrives in the background', () async {
    final monday = weekOf(dayOf(DateTime.now()));
    final api = FakeSportivityApi(
      lessons: [
        for (var d = 0; d < 7; d++)
          lessonFixture(
            id: d + 1,
            start: monday.add(Duration(days: d, hours: 19)),
          ),
      ],
    );
    final container = build(api);
    await container.read(sessionProvider.future);

    // The first day does not wait for the week: one call for one day.
    final first = await container.read(scheduleProvider(monday).future);
    expect(first.single.id, 1);
    expect(api.scheduleCalls.first, (monday, addDays(monday, 1)));

    // After that the week is in and the other days cost nothing more.
    await container.read(scheduleWeekProvider(monday).future);
    for (var d = 1; d < 7; d++) {
      final lessons = await container.read(scheduleProvider(monday.add(Duration(days: d))).future);
      expect(lessons.single.id, d + 1);
    }
    expect(api.scheduleCalls, [(monday, addDays(monday, 1)), (monday, addDays(monday, 7))]);
  });

  test(
    'schedule: an empty day is asked for separately once (server that truncates the range)',
    () async {
      final monday = weekOf(dayOf(DateTime.now()));
      final wednesday = monday.add(const Duration(days: 2));
      final api = _TruncatingApi(
        lessons: [
          lessonFixture(id: 1, start: monday.add(const Duration(hours: 19))),
          lessonFixture(id: 3, start: wednesday.add(const Duration(hours: 19))),
        ],
      );
      final container = build(api);
      await container.read(sessionProvider.future);
      // With the (truncated) week already in, Wednesday looks empty and is therefore asked
      // for separately.
      await container.read(scheduleWeekProvider(monday).future);
      expect((await container.read(scheduleProvider(wednesday).future)).single.id, 3);
      expect(api.scheduleCalls, hasLength(2));
    },
  );

  test('lesson details are kept for a day and not fetched again on every sync', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final container = build(api);
    await container.read(sessionProvider.future);
    final booked = container.read(bookedLessonsProvider.notifier);

    await container.read(bookedLessonsProvider.future);
    await booked.refreshAndSync();
    await booked.refreshAndSync();
    expect(api.lessonCalls, [5]);
    // The details (trainer) are there, the status comes from the fresh list.
    expect(container.read(bookedLessonsProvider).value!.single.trainer, 'Anna');
  });

  test('a rescheduled lesson does get fresh details', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final container = build(api);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.future);

    api.lessons = [
      lessonFixture(id: 5, start: tomorrow.add(const Duration(hours: 1)), status: 'Booked'),
    ];
    await container.read(bookedLessonsProvider.notifier).refreshAndSync();
    expect(api.lessonCalls, [5, 5]);
  });

  test('history: who taught the lesson is fetched once and remembered after that', () async {
    final past = dayOf(DateTime.now()).subtract(const Duration(days: 12, hours: -20));
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 9, start: past, status: 'Booked', trainer: 'Ruben Smit')],
    );
    final cache = FakeCacheService();
    final container = build(api, cache: cache);
    await container.read(sessionProvider.future);

    // The list itself is thin…
    expect((await container.read(lessonHistoryProvider.future)).single.trainer, isNull);
    // …the card fetches the trainer, and does not ask for it again afterwards.
    expect((await container.read(pastLessonProvider(9).future))?.trainer, 'Ruben Smit');
    expect((await container.read(pastLessonProvider(9).future))?.trainer, 'Ruben Smit');
    expect(api.lessonCalls, [9]);

    // Not after an app restart either: it is in the persistent cache.
    final restarted = build(api, cache: cache);
    await restarted.read(sessionProvider.future);
    expect((await restarted.read(pastLessonProvider(9).future))?.trainer, 'Ruben Smit');
    expect(api.lessonCalls, [9]);
  });

  test('history: a lesson the server no longer knows is not requested endlessly', () async {
    final api = _FlakyApi(lessons: const []);
    final container = build(api);
    await container.read(sessionProvider.future);
    expect(await container.read(pastLessonProvider(404).future), isNull);
    container.invalidate(pastLessonProvider(404));
    expect(await container.read(pastLessonProvider(404).future), isNull);
    expect(api.attempts, 1);
  });

  test('choosing a calendar and syncing right away writes to that calendar', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = FakeCalendarTarget();
    final settings = FakeSettingsService();
    final container = build(api, settings: settings, target: target);
    await container.read(sessionProvider.future);
    // Load the old state first (sync off), as the settings screen does.
    expect((await container.read(syncProvider.future)).enabled, isFalse);

    await container
        .read(syncProvider.notifier)
        .choose(
          SyncTargetKind.calDav,
          calendar: const CalendarInfo(id: 'cal', name: 'Sport'),
        );
    final booked = await container.read(bookedLessonsProvider.future);
    final result = await container.read(syncProvider.notifier).run(booked);

    expect(result?.created, 1);
    expect(target.events.values.single.uid, lessonUid(5));
  });

  test('sync off: booking touches no calendar', () async {
    final api = FakeSportivityApi(lessons: [lessonFixture(id: 5, start: tomorrow)]);
    final target = FakeCalendarTarget();
    final container = build(api, target: target);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.future);
    await container.read(bookedLessonsProvider.notifier).book(api.lessons.single);
    expect(target.events, isEmpty);
  });

  test('choosing another target cleans up the old one', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = FakeCalendarTarget();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'old');
    final container = build(api, settings: settings, target: target);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.notifier).refreshAndSync();
    expect(target.events, hasLength(1));

    await container.read(syncProvider.notifier).choose(SyncTargetKind.off);
    expect(target.events, isEmpty);
    expect(settings.sync.enabled, isFalse);
  });

  test('a booking that went through is not reported as failed when the refresh fails', () async {
    final api = _FailsAfterBookingApi(lessons: [lessonFixture(id: 5, start: tomorrow)]);
    final container = build(api);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.future);

    final result = await container.read(bookedLessonsProvider.notifier).book(api.lessons.single);
    expect(result.success, isTrue);
    expect(api.joined, [(5, false)]);
  });

  test('a list that arrives during a sync is synced right after it, not dropped', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = _GatedCalendar();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
    final container = build(api, settings: settings, target: target);
    await container.read(sessionProvider.future);
    final sync = container.read(syncProvider.notifier);
    final first = await container.read(bookedLessonsProvider.future);

    // The sync at start-up is busy writing lesson 5…
    final running = sync.run(first);
    await pumpEventQueue();
    expect(target.started, hasLength(1));

    // …when lesson 6 is booked.
    final six = lessonFixture(id: 6, start: tomorrow, status: 'Booked');
    expect(await sync.run([...first, six]), isNull);

    target.release();
    await pumpEventQueue();
    target.release();
    await running;
    expect(target.events.values.map((e) => e.uid), containsAll([lessonUid(5), lessonUid(6)]));
  });

  test('when the background task holds the lock, the app waits and then writes', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = FakeCalendarTarget();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
    // Busy the first two times, as if the background task were writing.
    var busy = 2;
    Future<T?> lock<T>(Future<T> Function() action) async => busy-- > 0 ? null : action();
    final saved = SyncNotifier.lockRetryDelay;
    SyncNotifier.lockRetryDelay = Duration.zero;
    addTearDown(() => SyncNotifier.lockRetryDelay = saved);
    final container = build(api, settings: settings, target: target, lock: lock);

    await container.read(sessionProvider.future);
    final result = await container.read(bookedLessonsProvider.notifier).refreshAndSync();
    expect(result?.created, 1);
    expect(target.events.values.single.uid, lessonUid(5));
  });

  test('sync off: booking touches no calendar', () async {
    final api = FakeSportivityApi(lessons: [lessonFixture(id: 5, start: tomorrow)]);
    final target = FakeCalendarTarget();
    final container = build(api, target: target);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.future);
    await container.read(bookedLessonsProvider.notifier).book(api.lessons.single);
    expect(target.events, isEmpty);
  });

  test('choosing another target cleans up the old one', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = FakeCalendarTarget();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'old');
    final container = build(api, settings: settings, target: target);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.notifier).refreshAndSync();
    expect(target.events, hasLength(1));

    await container.read(syncProvider.notifier).choose(SyncTargetKind.off);
    expect(target.events, isEmpty);
    expect(settings.sync.enabled, isFalse);
  });

  test('a booking that went through is not reported as failed when the refresh fails', () async {
    final api = _FailsAfterBookingApi(lessons: [lessonFixture(id: 5, start: tomorrow)]);
    final container = build(api);
    await container.read(sessionProvider.future);
    await container.read(bookedLessonsProvider.future);

    final result = await container.read(bookedLessonsProvider.notifier).book(api.lessons.single);
    expect(result.success, isTrue);
    expect(api.joined, [(5, false)]);
  });

  test('a list that arrives during a sync is synced right after it, not dropped', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = _GatedCalendar();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
    final container = build(api, settings: settings, target: target);
    await container.read(sessionProvider.future);
    final sync = container.read(syncProvider.notifier);
    final first = await container.read(bookedLessonsProvider.future);

    // The sync at start-up is busy writing lesson 5…
    final running = sync.run(first);
    await pumpEventQueue();
    expect(target.started, hasLength(1));

    // …when lesson 6 is booked.
    final six = lessonFixture(id: 6, start: tomorrow, status: 'Booked');
    expect(await sync.run([...first, six]), isNull);

    target.release();
    await pumpEventQueue();
    target.release();
    await running;
    expect(target.events.values.map((e) => e.uid), containsAll([lessonUid(5), lessonUid(6)]));
  });

  test('when the background task holds the lock, the app waits and then writes', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = FakeCalendarTarget();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
    // Busy the first two times, as if the background task were writing.
    var busy = 2;
    Future<T?> lock<T>(Future<T> Function() action) async => busy-- > 0 ? null : action();
    final saved = SyncNotifier.lockRetryDelay;
    SyncNotifier.lockRetryDelay = Duration.zero;
    addTearDown(() => SyncNotifier.lockRetryDelay = saved);
    final container = build(api, settings: settings, target: target, lock: lock);

    await container.read(sessionProvider.future);
    final result = await container.read(bookedLessonsProvider.notifier).refreshAndSync();
    expect(result?.created, 1);
    expect(target.events.values.single.uid, lessonUid(5));
  });

  test('a sync does not undo a setting changed while it ran', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = _GatedCalendar();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
    final container = build(api, settings: settings, target: target);
    await container.read(sessionProvider.future);
    final sync = container.read(syncProvider.notifier);

    final running = sync.run(await container.read(bookedLessonsProvider.future));
    await pumpEventQueue();
    await sync.setReminder(30);
    target.release();
    await running;

    expect(settings.sync.reminderMinutes, 30);
    expect(settings.sync.lastRun, isNotNull);
  });

  test('the background fetch asks the server once, not twice', () async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final target = FakeCalendarTarget();
    final settings = FakeSettingsService()
      ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
    final container = build(api, settings: settings, target: target);
    final session = await container.read(sessionProvider.future);

    // What backgroundSyncDispatcher does.
    final lessons = await container.read(bookedLessonsFetcherProvider).fetch(session.location!.id);
    await container.read(syncProvider.notifier).run(lessons);

    expect(api.bookedCalls, hasLength(1));
    expect(api.lessonCalls, [5]);
    expect(target.events.values.single.uid, lessonUid(5));
  });

  group('days are calendar days, also when summer time ends', () {
    // 25 October 2026: in Europe/Amsterdam that day has 25 hours. CI runs with that TZ; the
    // expectations hold in any zone.
    final sunday = DateTime(2026, 10, 25);

    test('addDays', () {
      expect(addDays(sunday, 1), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 10, 19), 7), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 3, 29), 1), DateTime(2026, 3, 30));
      expect(addDays(sunday, -365), DateTime(2025, 10, 25));
    });

    test('the schedule asks for the day and the week up to the next midnight', () async {
      final api = FakeSportivityApi();
      final container = build(api);
      await container.read(sessionProvider.future);

      await container.read(scheduleProvider(sunday).future);
      await container.read(scheduleWeekProvider(weekOf(sunday)).future);
      expect(api.scheduleCalls, [
        (sunday, DateTime(2026, 10, 26)),
        (DateTime(2026, 10, 19), DateTime(2026, 10, 26)),
      ]);
    });
  });
}
