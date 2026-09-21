import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../services/cache_service.dart';
import '../services/sportivity_api.dart';
import 'services.dart';
import 'session_provider.dart';
import 'sync_provider.dart';

/// How far ahead booked lessons are fetched and synchronised.
const kBookedWindow = Duration(days: 56);

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// True while a list on screen came from the cache because the server could not be reached.
/// Reported from inside provider builds, hence the microtask: Riverpod does not allow one
/// provider to change another while it is still being built.
class OfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void report({required bool offline}) {
    Future.microtask(() {
      if (ref.mounted && state != offline) state = offline;
    });
  }
}

final offlineProvider = NotifierProvider<OfflineNotifier, bool>(OfflineNotifier.new);

/// The Monday of the week [day] falls in.
DateTime weekOf(DateTime day) => DateTime(day.year, day.month, day.day - (day.weekday - 1));

/// The schedule of a whole week in a single call, kept as stock: days that are in here cost
/// no further request and no waiting. Stays around for ten minutes after the last screen
/// looked at it; refreshing fetches it again.
final scheduleWeekProvider = FutureProvider.autoDispose.family<List<Lesson>, DateTime>((
  ref,
  monday,
) async {
  final api = ref.watch(apiProvider);
  final cache = ref.watch(cacheServiceProvider);
  final locationId = ref.watch(locationIdProvider);

  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 10), link.close);
  ref.onDispose(timer.cancel);

  final key = 'schedule:$locationId:${monday.toIso8601String().substring(0, 10)}';
  try {
    final lessons = await api.schedule(locationId, monday, monday.add(const Duration(days: 7)));
    await cache.saveLessons(key, lessons);
    ref.read(offlineProvider.notifier).report(offline: false);
    return lessons;
  } on SportivityException {
    // No connection: whatever was there last time.
    final cached = await cache.loadLessons(key);
    if (cached.isEmpty) rethrow;
    ref.read(offlineProvider.notifier).report(offline: true);
    return cached;
  }
});

/// The schedule of a single day.
///
/// Requesting a whole week is noticeably heavier for the server than a single day, so
/// waiting for the week made the first screen slow. Hence: if the week is already there,
/// the day comes out of it (instantly). If not, only this day is fetched — and the week
/// only afterwards, in the background, so the *next* day you tap is there right away.
final scheduleProvider = FutureProvider.autoDispose.family<List<Lesson>, DateTime>((
  ref,
  day,
) async {
  final api = ref.watch(apiProvider);
  final locationId = ref.watch(locationIdProvider);
  final monday = weekOf(day);
  List<Lesson> ofDay(List<Lesson> lessons) => lessons.where((l) => dayOf(l.start) == day).toList();

  // exists before read: merely reading would trigger the week fetch, which is exactly what
  // has to wait until this day is in. And read, not watch: when the week arrives later,
  // this day does not need to reload.
  final weekProvider = scheduleWeekProvider(monday);
  final week = ref.exists(weekProvider) ? ref.read(weekProvider).value : null;
  if (week != null) {
    final lessons = ofDay(week);
    // An empty day in a filled week may be a rest day, but also a server that cuts the
    // range short; in that case simply ask for the day on its own below.
    if (lessons.isNotEmpty) return lessons;
  }

  final List<Lesson> lessons;
  try {
    lessons = ofDay(await api.schedule(locationId, day, day.add(const Duration(days: 1))));
    ref.read(offlineProvider.notifier).report(offline: false);
  } on SportivityException {
    // No connection: the week that was saved last time still has this day in it. Straight
    // from the cache rather than through the week provider: that one would fail too, and an
    // auto-dispose provider that fails while nobody listens surfaces as a vague "disposed
    // during loading" instead of "no connection".
    final key = 'schedule:$locationId:${monday.toIso8601String().substring(0, 10)}';
    final cached = ofDay(await ref.read(cacheServiceProvider).loadLessons(key));
    if (cached.isEmpty) rethrow;
    ref.read(offlineProvider.notifier).report(offline: true);
    return cached;
  }
  if (week == null) {
    // Do not await and ignore errors: this is a head start, not a precondition.
    unawaited(ref.read(scheduleWeekProvider(monday).future).then((_) {}, onError: (_) {}));
  }
  return lessons;
});

/// Fetches the week of [day] again.
Future<void> refreshSchedule(WidgetRef ref, DateTime day) async {
  ref.invalidate(scheduleWeekProvider(weekOf(day)));
  await ref.read(scheduleProvider(day).future);
}

class BookedLessonsNotifier extends AsyncNotifier<List<Lesson>> {
  @override
  Future<List<Lesson>> build() async {
    final locationId = ref.watch(locationIdProvider);
    final cache = ref.watch(cacheServiceProvider);
    final key = 'booked:$locationId';
    try {
      final lessons = await _fetch(locationId);
      await cache.saveLessons(key, lessons);
      ref.read(offlineProvider.notifier).report(offline: false);
      return lessons;
    } on SportivityException {
      final cached = await cache.loadLessons(key);
      if (cached.isEmpty) rethrow;
      ref.read(offlineProvider.notifier).report(offline: true);
      return cached;
    }
  }

  Future<List<Lesson>> _fetch(int locationId) async {
    final from = dayOf(DateTime.now());
    final thin = await ref
        .read(apiProvider)
        .bookedLessons(locationId, from, from.add(kBookedWindow));
    return _withDetails(thin);
  }

  /// How long fetched lesson details stay valid. Trainer, room and description rarely
  /// change; the times and the status always come fresh from the list.
  static const _detailsMaxAge = Duration(hours: 24);

  /// The list of booked lessons is the thin variant: no trainer, room or description. For
  /// a complete calendar event every lesson is fetched separately — but not every time:
  /// the sync runs after every booking and every three hours on Android, and that is
  /// somebody else's server. Details are kept for a day and only fetched again when the
  /// lesson has been rescheduled. If fetching fails, the thin version stays.
  Future<List<Lesson>> _withDetails(List<Lesson> thin) async {
    final api = ref.read(apiProvider);
    final cache = ref.read(cacheServiceProvider);
    final known = await cache.loadDetails();
    final now = DateTime.now();

    bool fresh(Lesson lesson) {
      final hit = known[lesson.id];
      return hit != null &&
          now.difference(hit.fetchedAt) < _detailsMaxAge &&
          hit.lesson.startUtc == lesson.startUtc &&
          hit.lesson.endUtc == lesson.endUtc;
    }

    final missing = [
      for (final l in thin)
        if (!fresh(l)) l,
    ];
    const batch = 4;
    for (var i = 0; i < missing.length; i += batch) {
      await Future.wait([
        for (final lesson in missing.skip(i).take(batch))
          api
              .lesson(lesson.id)
              .then<void>((full) => known[lesson.id] = (lesson: full, fetchedAt: now))
              .catchError((_) {}),
      ]);
    }
    // Only keep what is still booked; the rest is of no use any more.
    final ids = {for (final l in thin) l.id};
    known.removeWhere((id, _) => !ids.contains(id));
    await cache.saveDetails(known);

    return [
      for (final lesson in thin)
        known[lesson.id]?.lesson.copyWith(bookingStatus: lesson.bookingStatus) ?? lesson,
    ];
  }

  /// Fetches again and then updates the calendar. Only after a successful fetch: an empty
  /// list caused by a network error must never empty the calendar.
  Future<void> refreshAndSync() async {
    final locationId = ref.read(locationIdProvider);
    final lessons = await _fetch(locationId);
    await ref.read(cacheServiceProvider).saveLessons('booked:$locationId', lessons);
    state = AsyncData(lessons);
    await ref.read(syncProvider.notifier).run(lessons);
  }

  Future<BookingResult> book(Lesson lesson, {bool buy = false}) async {
    final result = await ref
        .read(apiProvider)
        .joinLesson(lesson.id, ref.read(locationIdProvider), buy: buy);
    if (result.success) await _afterChange(lesson);
    return result;
  }

  Future<BookingResult> cancel(Lesson lesson) async {
    final result = await ref
        .read(apiProvider)
        .cancelLesson(lesson.id, ref.read(locationIdProvider));
    if (result.success) await _afterChange(lesson);
    return result;
  }

  Future<void> _afterChange(Lesson lesson) async {
    ref.invalidate(scheduleWeekProvider(weekOf(dayOf(lesson.start))));
    ref.invalidate(lessonProvider(lesson.id));
    await refreshAndSync();
  }
}

final bookedLessonsProvider = AsyncNotifierProvider<BookedLessonsNotifier, List<Lesson>>(
  BookedLessonsNotifier.new,
);

/// How far back "History" looks.
const kHistoryWindow = Duration(days: 365);

/// Past lessons, newest first. Read-only: the calendar sync does not look at these.
final lessonHistoryProvider = FutureProvider.autoDispose<List<Lesson>>((ref) async {
  final api = ref.watch(apiProvider);
  final today = dayOf(DateTime.now());
  final lessons = await api.bookedLessons(
    ref.watch(locationIdProvider),
    today.subtract(kHistoryWindow),
    today,
  );
  return lessons.where((l) => l.isPast).toList()..sort((a, b) => b.startUtc.compareTo(a.startUtc));
});

/// The details of lessons that have taken place, stored permanently. The history list is
/// the thin variant (no trainer, no room); who taught the lesson comes from a separate call
/// per lesson. That call only happens for cards that scroll into view, exactly once per
/// lesson.
class PastLessonDetails {
  PastLessonDetails(this._api, this._cache);

  final SportivityApi _api;
  final CacheService _cache;

  static const _key = 'history-details';
  Future<Map<int, CachedLesson>>? _loaded;
  final _failed = <int>{};
  final _pending = <int, Future<Lesson?>>{};

  /// From the cache, otherwise from the server, once. Null if the server does not know the
  /// lesson (any more); that is not retried during this session.
  Future<Lesson?> load(int lessonId) async {
    final known = await (_loaded ??= _cache.loadDetails(key: _key));
    if (known[lessonId] case final hit?) return hit.lesson;
    if (_failed.contains(lessonId)) return null;
    // Mind the braces: `() => _pending.remove(id)` would return the removed future, and
    // whenComplete waits for whatever its callback returns — so for itself.
    return _pending[lessonId] ??= _fetch(known, lessonId).whenComplete(() {
      _pending.remove(lessonId);
    });
  }

  Future<Lesson?> _fetch(Map<int, CachedLesson> known, int lessonId) async {
    try {
      final lesson = await _api.lesson(lessonId);
      known[lessonId] = (lesson: lesson, fetchedAt: DateTime.now());
      await _cache.saveDetails(known, key: _key);
      return lesson;
    } on Exception {
      _failed.add(lessonId);
      return null;
    }
  }
}

final pastLessonDetailsProvider = Provider<PastLessonDetails>((ref) {
  // A new session starts with an empty memory; the persistent cache has already been wiped
  // on logout.
  ref.watch(sessionProvider.select((s) => s.value?.loggedIn));
  return PastLessonDetails(ref.watch(apiProvider), ref.watch(cacheServiceProvider));
});

/// A single lesson from the history, completed with trainer and room once they are known.
final pastLessonProvider = FutureProvider.autoDispose.family<Lesson?, int>(
  (ref, id) => ref.watch(pastLessonDetailsProvider).load(id),
);

final lessonProvider = FutureProvider.autoDispose.family<Lesson, int>((ref, id) async {
  final api = ref.watch(apiProvider);
  return api.lesson(id);
});

final likedLessonsProvider = FutureProvider.autoDispose<List<Lesson>>((ref) async {
  final api = ref.watch(apiProvider);
  return api.likedLessons(ref.watch(locationIdProvider));
});
