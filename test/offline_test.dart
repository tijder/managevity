import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// A server that can be unplugged.
class _UnpluggableApi extends FakeSportivityApi {
  _UnpluggableApi({super.lessons});

  var online = true;

  void _check() {
    if (!online) throw const SportivityException(AppError.network);
  }

  @override
  Future<List<Lesson>> schedule(int locationId, DateTime from, DateTime to) async {
    _check();
    return super.schedule(locationId, from, to);
  }

  @override
  Future<List<Lesson>> bookedLessons(int locationId, DateTime from, DateTime to) async {
    _check();
    return super.bookedLessons(locationId, from, to);
  }
}

/// A calendar that refuses every write.
class _BrokenCalendar implements CalendarSyncTarget {
  @override
  Future<List<CalendarInfo>> listCalendars() async => const [];

  @override
  Future<WrittenEvent> upsert(String calendarId, CalendarEvent event, {WrittenEvent? existing}) =>
      throw const CalendarSyncException(AppError.calendarAuth, statusCode: 401);

  @override
  Future<void> delete(String calendarId, WrittenEvent existing) async {}
}

void main() {
  final today = dayOf(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1, hours: 19));

  (ProviderContainer, FakeCacheService) build(
    FakeSportivityApi api, {
    FakeSettingsService? settings,
    CalendarSyncTarget? target,
    FakeCacheService? cache,
  }) {
    api.session = const Session(token: 'fake');
    final sharedCache = cache ?? FakeCacheService();
    final container = ProviderContainer(
      // As in main.dart: no automatic retries, so a failure is a failure.
      retry: (_, _) => null,
      overrides: [
        apiProvider.overrideWithValue(api),
        credentialStoreProvider.overrideWithValue(FakeCredentialStore(session: api.session)),
        settingsServiceProvider.overrideWithValue(settings ?? FakeSettingsService()),
        cacheServiceProvider.overrideWithValue(sharedCache),
        syncIndexStoreProvider.overrideWithValue(MemorySyncIndexStore()),
        syncTargetFactoryProvider.overrideWithValue((_) async => target),
        syncLockProvider.overrideWithValue(noSyncLock),
      ],
    );
    addTearDown(container.dispose);
    return (container, sharedCache);
  }

  /// Lets the microtask that carries the offline report run.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'schedule: offline falls back to the saved week and says so; back online clears it',
    () async {
      final api = _UnpluggableApi(lessons: [lessonFixture(id: 1, start: tomorrow)]);
      final (first, cache) = build(api);
      await first.read(sessionProvider.future);
      final day = dayOf(tomorrow);

      // A normal visit fills the cache (the day first, then the week in the background).
      expect((await first.read(scheduleProvider(day).future)).single.id, 1);
      await first.read(scheduleWeekProvider(weekOf(day)).future);
      await settle();
      expect(first.read(offlineProvider), isFalse);

      // The next app start is without a connection.
      api.online = false;
      final (second, _) = build(api, cache: cache);
      await second.read(sessionProvider.future);
      expect((await second.read(scheduleProvider(day).future)).single.id, 1);
      await settle();
      expect(second.read(offlineProvider), isTrue);

      // Connection back, refresh: the notice goes away.
      api.online = true;
      second.invalidate(scheduleWeekProvider(weekOf(day)));
      second.invalidate(scheduleProvider(day));
      await second.read(scheduleProvider(day).future);
      await settle();
      expect(second.read(offlineProvider), isFalse);
    },
  );

  test('schedule: offline with nothing saved is an error, not an empty day', () async {
    final api = _UnpluggableApi(lessons: [lessonFixture(id: 1, start: tomorrow)])..online = false;
    final (container, _) = build(api);
    await container.read(sessionProvider.future);
    // Listen like a screen does: an auto-dispose provider nobody listens to is thrown away
    // mid-load, and then the error you get is about that instead of the real one.
    final provider = scheduleProvider(dayOf(tomorrow));
    container.listen(provider, (_, _) {});
    await expectLater(
      container.read(provider.future),
      throwsA(isA<SportivityException>().having((e) => e.code, 'code', AppError.network)),
    );
  });

  test('my lessons: offline shows the saved bookings and raises the notice', () async {
    final api = _UnpluggableApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    final (first, cache) = build(api);
    await first.read(sessionProvider.future);
    await first.read(bookedLessonsProvider.future);

    api.online = false;
    final (second, _) = build(api, cache: cache);
    await second.read(sessionProvider.future);
    expect((await second.read(bookedLessonsProvider.future)).single.id, 5);
    await settle();
    expect(second.read(offlineProvider), isTrue);
  });

  test(
    'a calendar that refuses a lesson leaves a readable "last error", not a raw exception',
    () async {
      final api = FakeSportivityApi(
        lessons: [lessonFixture(id: 5, description: 'Yoga', start: tomorrow, status: 'Booked')],
      );
      final settings = FakeSettingsService()
        ..sync = const SyncSettings(kind: SyncTargetKind.calDav, calendarId: 'cal');
      final (container, _) = build(api, settings: settings, target: _BrokenCalendar());
      await container.read(sessionProvider.future);
      await container.read(bookedLessonsProvider.notifier).refreshAndSync();

      final message = settings.sync.lastError!;
      expect(message, startsWith('Yoga: '));
      expect(message, isNot(contains('Exception')));
      expect(message, isNot(contains('verwijderen')));
      // Whatever the system locale of the machine running this: a real sentence.
      expect(message.length, greaterThan('Yoga: '.length + 10));
    },
  );
}
