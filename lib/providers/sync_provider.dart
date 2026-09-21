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
  bool _running = false;

  @override
  Future<SyncSettings> build() => ref.watch(settingsServiceProvider).getSync();

  Future<void> _store(SyncSettings settings) async {
    await ref.read(settingsServiceProvider).setSync(settings);
    state = AsyncData(settings);
  }

  /// Writes [booked] to the chosen calendar. Does nothing when sync is switched off.
  Future<SyncResult?> run(List<Lesson> booked) async {
    final settings = await future;
    final scope = settings.scope;
    if (scope == null || _running) return null;
    _running = true;
    try {
      final target = await ref.read(syncTargetFactoryProvider)(settings.kind);
      if (target == null) {
        await _store(settings.copyWith(lastError: _eventL10n().errorCalendarUnavailable));
        return null;
      }
      final now = DateTime.now();
      // Without an address or coordinates the event is barer, but the sync carries on.
      final venue = await ref.read(venueProvider.future).catchError((_) => const Venue());
      final reminder = settings.reminderMinutes == null
          ? null
          : Duration(minutes: settings.reminderMinutes!);
      final engine = SyncEngine(target: target, store: ref.read(syncIndexStoreProvider));
      // Across isolates: the background task and the app must not write at the same time.
      final result = await ref.read(syncLockProvider)(
        () => engine.sync(
          calendarId: settings.calendarId!,
          booked: {
            for (final l in booked) l.id: eventForLesson(l, venue: venue, reminder: reminder),
          },
          windowStart: DateTime(now.year, now.month, now.day).toUtc(),
        ),
      );
      // null: another isolate is already syncing; it will update the status.
      if (result == null) return null;
      await _store(
        result.ok
            ? settings.copyWith(lastRun: now, clearError: true)
            : settings.copyWith(lastRun: now, lastError: _describeFailure(result.errors.first)),
      );
      return result;
    } on Exception catch (e) {
      await _store(settings.copyWith(lastError: describeError(_eventL10n(), e)));
      return null;
    } finally {
      _running = false;
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
    await _store(
      SyncSettings(
        kind: calendar == null ? SyncTargetKind.off : kind,
        calendarId: calendar?.id,
        calendarName: calendar?.name,
      ),
    );
  }

  /// The events are updated at the next sync: the reminder is part of the hash.
  Future<void> setReminder(int? minutes) async {
    final settings = await future;
    await _store(settings.copyWith(reminderMinutes: minutes, clearReminder: minutes == null));
  }

  Future<List<CalendarInfo>> listCalendars(SyncTargetKind kind) async {
    final target = await ref.read(syncTargetFactoryProvider)(kind);
    if (target == null) throw const CalendarSyncException(AppError.calendarUnavailable);
    return target.listCalendars();
  }

  Future<void> saveCalDav(CalDavCredentials credentials) =>
      ref.read(credentialStoreProvider).writeCalDav(credentials);
}

final syncProvider = AsyncNotifierProvider<SyncNotifier, SyncSettings>(SyncNotifier.new);
