import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../models/customer.dart';
import '../models/lesson.dart';
import '../models/sync_settings.dart';
import '../services/calendar/caldav_target.dart';
import '../services/calendar/calendar_sync_target.dart';
import '../services/calendar/device_calendar_target.dart';
import '../services/calendar/sync_engine.dart';
import '../services/credential_store.dart';
import '../services/sync_lock.dart';
import '../utils/address.dart';
import '../utils/errors.dart';
import '../utils/html_text.dart';
import 'services.dart';
import 'session_provider.dart';

/// The device calendar only exists on Android; elsewhere CalDAV is what remains.
bool get deviceCalendarSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// What the API reveals about where the gym is. There is no address field: the address
/// comes from the free-form contact text (see `extractAddress`), the coordinates from
/// `UserContent`. Either can be missing.
class Venue {
  const Venue({this.address, this.geo});
  final String? address;
  final (double, double)? geo;
}

final venueProvider = FutureProvider<Venue>((ref) async {
  final api = ref.watch(apiProvider);
  final locationId = ref.watch(locationIdProvider);
  final results = await Future.wait<Object?>([
    api.contactInformationHtml(locationId).then<Object?>((v) => v).catchError((_) => null),
    api.userContent(locationId: locationId).then<Object?>((v) => v).catchError((_) => null),
  ]);
  final html = results[0] as String?;
  final content = results[1] as UserContent?;
  final lat = content?.latitude, lon = content?.longitude;
  return Venue(
    address: html == null ? null : extractAddress(htmlToText(html)),
    geo: lat != null && lon != null ? (lat, lon) : null,
  );
});

/// The texts in a calendar event have no BuildContext (the sync also runs in the
/// background), so the system language decides.
AppLocalizations _eventL10n() {
  final locale = PlatformDispatcher.instance.locale;
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );
  return lookupAppLocalizations(supported ? Locale(locale.languageCode) : const Locale('en'));
}

CalendarEvent eventForLesson(
  Lesson lesson, {
  Venue venue = const Venue(),
  Duration? reminder,
  AppLocalizations? l10n,
}) {
  final t = l10n ?? _eventL10n();
  final info = lesson.additionalInformation;
  return CalendarEvent(
    uid: lessonUid(lesson.id),
    title: lesson.description,
    startUtc: lesson.startUtc,
    endUtc: lesson.endUtc,
    // Room, name and address: that way a maps app finds the way and you see where to be.
    location: [lesson.room, lesson.locationName, venue.address].nonNulls.join(', '),
    description: [
      if (lesson.bookingStatus.isWaitingList) t.eventWaitingList,
      if (lesson.trainer != null) '${t.lessonTrainer}: ${lesson.trainer}',
      if (lesson.room != null) '${t.lessonRoom}: ${lesson.room}',
      if (lesson.group != null) lesson.group!,
      if (lesson.maximumParticipants != null) t.eventSpots(lesson.maximumParticipants!),
      // The API delivers HTML; a calendar wants plain text.
      if (info != null) '\n${htmlToText(info)}',
    ].join('\n').trim(),
    tentative: lesson.bookingStatus.isWaitingList,
    categories: [?lesson.activity],
    geo: venue.geo,
    reminder: reminder,
  );
}

/// The lock around every write to the calendar; tests plug in a pass-through.
typedef SyncLock = Future<T?> Function<T>(Future<T> Function() action);

final syncLockProvider = Provider<SyncLock>((ref) => withSyncLock);

/// Builds the target for [kind]; null if that is impossible (no CalDAV credentials, not
/// Android).
typedef SyncTargetFactory = Future<CalendarSyncTarget?> Function(SyncTargetKind kind);

final syncTargetFactoryProvider = Provider<SyncTargetFactory>((ref) {
  final store = ref.watch(credentialStoreProvider);
  return (kind) async {
    switch (kind) {
      case SyncTargetKind.off:
        return null;
      case SyncTargetKind.deviceCalendar:
        return deviceCalendarSupported ? DeviceCalendarTarget() : null;
      case SyncTargetKind.calDav:
        final c = await store.readCalDav();
        if (c == null) return null;
        return CalDavTarget(baseUrl: c.baseUrl, username: c.username, password: c.password);
    }
  };
});

String _describeFailure(SyncFailure failure) {
  final l10n = _eventL10n();
  return l10n.syncFailedFor(
    failure.lessonTitle ?? l10n.syncRemoveFailed,
    describeError(l10n, failure.error),
  );
}

class SyncNotifier extends AsyncNotifier<SyncSettings> {
  /// The sync loop in progress, if any; see [run].
  Future<SyncResult?>? _loop;

  /// A newer list that arrived while a sync was running: synced right after it.
  List<Lesson>? _queued;

  /// How long to wait, and how often, when the background task holds the lock.
  @visibleForTesting
  static Duration lockRetryDelay = const Duration(seconds: 10);
  static const _lockRetries = 6;

  @override
  Future<SyncSettings> build() => ref.watch(settingsServiceProvider).getSync();

  /// Completes when no sync is running (any more).
  Future<void> get idle async {
    while (_loop != null) {
      await _loop;
    }
  }

  /// Applies [change] to the settings as they are *now* in storage, not as they were when a
  /// sync started: the user may have changed the reminder meanwhile, and the background
  /// task (another isolate) may have written a status.
  Future<void> _update(SyncSettings Function(SyncSettings) change) async {
    final service = ref.read(settingsServiceProvider);
    final settings = change(await service.getSync());
    await service.setSync(settings);
    if (ref.mounted) state = AsyncData(settings);
  }

  /// Records the outcome of a sync, unless the target changed while it ran.
  Future<void> _record(SyncSettings ranWith, SyncSettings Function(SyncSettings) change) =>
      _update((now) => now.scope == ranWith.scope ? change(now) : now);

  /// Writes [booked] to the chosen calendar. Does nothing when sync is switched off.
  ///
  /// Never drops a list: one that arrives while a sync runs (a booking during the sync at
  /// start-up) is synced right after it, and when the background task holds the lock this
  /// waits for it rather than giving up. Returns the result of the last round; null when
  /// the list was handed to a sync already running, or nothing was written.
  Future<SyncResult?> run(List<Lesson> booked) {
    if (_loop != null) {
      _queued = booked;
      return Future.value();
    }
    // Mind the braces: see the whenComplete pitfall in CLAUDE.md.
    return _loop = _drain(booked).whenComplete(() {
      _loop = null;
    });
  }

  Future<SyncResult?> _drain(List<Lesson> booked) async {
    SyncResult? result;
    for (List<Lesson>? next = booked; next != null; next = _queued) {
      _queued = null;
      result = await _runOnce(next);
    }
    return result;
  }

  Future<SyncResult?> _runOnce(List<Lesson> booked) async {
    final settings = await future;
    if (settings.scope == null) return null;
    try {
      final target = await ref.read(syncTargetFactoryProvider)(settings.kind);
      if (target == null) {
        await _record(
          settings,
          (s) => s.copyWith(lastError: _eventL10n().errorCalendarUnavailable),
        );
        return null;
      }
      final now = DateTime.now();
      // Without an address or coordinates the event is barer, but the sync carries on.
      final venue = await ref.read(venueProvider.future).catchError((_) => const Venue());
      final reminder = settings.reminderMinutes == null
          ? null
          : Duration(minutes: settings.reminderMinutes!);
      final engine = SyncEngine(target: target, store: ref.read(syncIndexStoreProvider));
      Future<SyncResult> sync() => engine.sync(
        calendarId: settings.calendarId!,
        booked: {for (final l in booked) l.id: eventForLesson(l, venue: venue, reminder: reminder)},
        windowStart: DateTime(now.year, now.month, now.day).toUtc(),
      );
      // Across isolates: the background task and the app must not write at the same time.
      // null: the other one is busy. Its list may predate a booking made here, so wait for
      // it and then write ours.
      final lock = ref.read(syncLockProvider);
      var result = await lock(sync);
      for (var i = 0; result == null && i < _lockRetries && ref.mounted; i++) {
        await Future<void>.delayed(lockRetryDelay);
        result = await lock(sync);
      }
      if (result == null) return null;
      await _record(
        settings,
        (s) => result!.ok
            ? s.copyWith(lastRun: now, clearError: true)
            : s.copyWith(lastRun: now, lastError: _describeFailure(result.errors.first)),
      );
      return result;
    } on Exception catch (e) {
      await _record(settings, (s) => s.copyWith(lastError: describeError(_eventL10n(), e)));
      return null;
    }
  }

  /// Chooses a different target. Whatever was written to the old target is removed from
  /// it first — otherwise lessons are left behind that nobody updates any more.
  Future<void> choose(SyncTargetKind kind, {CalendarInfo? calendar}) async {
    final old = await future;
    if (old.enabled && (old.kind != kind || old.calendarId != calendar?.id)) {
      final target = await ref.read(syncTargetFactoryProvider)(old.kind);
      if (target != null) {
        final engine = SyncEngine(target: target, store: ref.read(syncIndexStoreProvider));
        await ref.read(syncLockProvider)(() => engine.removeAll(old.calendarId!));
      }
    }
    await _update(
      (_) => SyncSettings(
        kind: calendar == null ? SyncTargetKind.off : kind,
        calendarId: calendar?.id,
        calendarName: calendar?.name,
      ),
    );
  }

  /// The events are updated at the next sync: the reminder is part of the hash.
  Future<void> setReminder(int? minutes) =>
      _update((s) => s.copyWith(reminderMinutes: minutes, clearReminder: minutes == null));

  Future<List<CalendarInfo>> listCalendars(SyncTargetKind kind) async {
    final target = await ref.read(syncTargetFactoryProvider)(kind);
    if (target == null) throw const CalendarSyncException(AppError.calendarUnavailable);
    return target.listCalendars();
  }

  Future<void> saveCalDav(CalDavCredentials credentials) =>
      ref.read(credentialStoreProvider).writeCalDav(credentials);
}

final syncProvider = AsyncNotifierProvider<SyncNotifier, SyncSettings>(SyncNotifier.new);
