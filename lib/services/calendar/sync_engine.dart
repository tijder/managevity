import 'calendar_sync_target.dart';

/// What the engine remembers about a single written lesson.
class SyncIndexEntry {
  const SyncIndexEntry({
    required this.lessonId,
    required this.ref,
    required this.hash,
    required this.startUtc,
    this.etag,
  });

  final int lessonId;
  final String ref;
  final String? etag;
  final String hash;
  final DateTime startUtc;

  WrittenEvent get written => WrittenEvent(ref: ref, etag: etag);

  Map<String, Object?> toJson() => {
    'lessonId': lessonId,
    'ref': ref,
    'etag': etag,
    'hash': hash,
    'startUtc': startUtc.toUtc().toIso8601String(),
  };

  factory SyncIndexEntry.fromJson(Map<Object?, Object?> json) => SyncIndexEntry(
    lessonId: json['lessonId'] as int,
    ref: json['ref'] as String,
    etag: json['etag'] as String?,
    hash: json['hash'] as String,
    startUtc: DateTime.parse(json['startUtc'] as String),
  );
}

/// The index belongs to one target calendar ([scope]); a different target starts empty.
abstract interface class SyncIndexStore {
  Future<Map<int, SyncIndexEntry>> load(String scope);
  Future<void> save(String scope, Map<int, SyncIndexEntry> entries);
}

class MemorySyncIndexStore implements SyncIndexStore {
  final _scopes = <String, Map<int, SyncIndexEntry>>{};

  @override
  Future<Map<int, SyncIndexEntry>> load(String scope) async => {...?_scopes[scope]};

  @override
  Future<void> save(String scope, Map<int, SyncIndexEntry> entries) async =>
      _scopes[scope] = {...entries};
}

/// One event that could not be written or removed. Carries the error itself rather than a
/// sentence: the engine has no idea what language the user reads, and a raw `toString()`
/// of an exception does not belong on a settings screen.
class SyncFailure {
  const SyncFailure({required this.error, this.lessonTitle});

  final Object error;

  /// The lesson being written; null when removing an event failed.
  final String? lessonTitle;
}

class SyncResult {
  const SyncResult({
    this.created = 0,
    this.updated = 0,
    this.deleted = 0,
    this.unchanged = 0,
    this.errors = const [],
  });

  final int created;
  final int updated;
  final int deleted;
  final int unchanged;
  final List<SyncFailure> errors;

  bool get ok => errors.isEmpty;
}

String lessonUid(int lessonId) => 'lesson-$lessonId@managevity.g4d.nl';

/// One-way sync: the booked lessons are the source of truth, the calendar follows.
///
/// The engine only ever touches events that are in its own index. Whatever someone puts in
/// the same calendar themselves stays put — even if it happens to look like a lesson.
class SyncEngine {
  SyncEngine({required this.target, required this.store, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final CalendarSyncTarget target;
  final SyncIndexStore store;
  final DateTime Function() _now;

  /// Index entries of lessons that are this far in the past are forgotten (the event stays).
  static const _forgetAfter = Duration(days: 30);

  /// [booked] holds the booked lessons within the fetched window that starts at
  /// [windowStart], keyed by LessonId. Only call this if that fetch succeeded: an empty map
  /// means "nothing booked" and therefore deletes everything in the index inside the window.
  Future<SyncResult> sync({
    required String calendarId,
    required Map<int, CalendarEvent> booked,
    required DateTime windowStart,
  }) async {
    final index = await store.load(calendarId);
    var created = 0, updated = 0, deleted = 0, unchanged = 0;
    final errors = <SyncFailure>[];

    for (final MapEntry(key: lessonId, value: event) in booked.entries) {
      final known = index[lessonId];
      if (known != null && known.hash == event.contentHash) {
        unchanged++;
        continue;
      }
      try {
        final written = await target.upsert(calendarId, event, existing: known?.written);
        index[lessonId] = SyncIndexEntry(
          lessonId: lessonId,
          ref: written.ref,
          etag: written.etag,
          hash: event.contentHash,
          startUtc: event.startUtc,
        );
        known == null ? created++ : updated++;
      } on Exception catch (e) {
        errors.add(SyncFailure(error: e, lessonTitle: event.title));
      }
    }

    final forgetBefore = _now().subtract(_forgetAfter);
    for (final entry in index.values.toList()) {
      if (booked.containsKey(entry.lessonId)) continue;
      if (entry.startUtc.isBefore(windowStart)) {
        // Outside the window: the lesson was not cancelled, it has taken place. The event stays.
        if (entry.startUtc.isBefore(forgetBefore)) index.remove(entry.lessonId);
        continue;
      }
      try {
        await target.delete(calendarId, entry.written);
        index.remove(entry.lessonId);
        deleted++;
      } on Exception catch (e) {
        errors.add(SyncFailure(error: e));
      }
    }

    await store.save(calendarId, index);
    return SyncResult(
      created: created,
      updated: updated,
      deleted: deleted,
      unchanged: unchanged,
      errors: errors,
    );
  }

  /// Removes everything the engine ever wrote to [calendarId]; for when the user picks a
  /// different target or turns the sync off.
  Future<SyncResult> removeAll(String calendarId) async {
    final index = await store.load(calendarId);
    var deleted = 0;
    final errors = <SyncFailure>[];
    for (final entry in index.values.toList()) {
      try {
        await target.delete(calendarId, entry.written);
        index.remove(entry.lessonId);
        deleted++;
      } on Exception catch (e) {
        errors.add(SyncFailure(error: e));
      }
    }
    await store.save(calendarId, index);
    return SyncResult(deleted: deleted, errors: errors);
  }
}
