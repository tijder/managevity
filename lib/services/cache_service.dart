import '../models/lesson.dart';
import 'calendar/sync_engine.dart';
import 'storage.dart';

/// Fetched lesson details together with the moment they were fetched.
typedef CachedLesson = ({Lesson lesson, DateTime fetchedAt});

/// Last known lessons, so that the schedule and "my lessons" still show something offline.
class CacheService {
  static const _boxName = 'lessons_v1';

  Future<IsolatedBox<dynamic>> _openBox() => openStorageBox(_boxName);

  Future<void> saveLessons(String key, List<Lesson> lessons) async {
    final box = await _openBox();
    await box.put(key, [for (final l in lessons) l.toJson()]);
  }

  Future<List<Lesson>> loadLessons(String key) async {
    final box = await _openBox();
    final raw = await box.get(key);
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) ?Lesson.tryFromJson(item.cast<String, dynamic>()),
    ];
  }

  /// [key] separates the booked lessons (short-lived, pruned) from the history
  /// (permanent: a lesson that has taken place no longer changes).
  Future<Map<int, CachedLesson>> loadDetails({String key = 'details'}) async {
    final raw = await (await _openBox()).get(key);
    if (raw is! List) return {};
    final result = <int, CachedLesson>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final lesson = item['lesson'];
      final at = DateTime.tryParse('${item['fetchedAt']}');
      final parsed = lesson is Map ? Lesson.tryFromJson(lesson.cast<String, dynamic>()) : null;
      if (parsed != null && at != null) result[parsed.id] = (lesson: parsed, fetchedAt: at);
    }
    return result;
  }

  Future<void> saveDetails(Map<int, CachedLesson> details, {String key = 'details'}) async =>
      (await _openBox()).put(key, [
        for (final d in details.values)
          {'lesson': d.lesson.toJson(), 'fetchedAt': d.fetchedAt.toIso8601String()},
      ]);

  Future<void> clear() async => (await _openBox()).clear();
}

class HiveSyncIndexStore implements SyncIndexStore {
  static const _boxName = 'sync_v1';

  Future<IsolatedBox<dynamic>> _openBox() => openStorageBox(_boxName);

  @override
  Future<Map<int, SyncIndexEntry>> load(String scope) async {
    final raw = await (await _openBox()).get(scope);
    if (raw is! List) return {};
    return {
      for (final item in raw)
        if (item is Map) (item['lessonId'] as int): SyncIndexEntry.fromJson(item),
    };
  }

  @override
  Future<void> save(String scope, Map<int, SyncIndexEntry> entries) async =>
      (await _openBox()).put(scope, [for (final e in entries.values) e.toJson()]);
}
