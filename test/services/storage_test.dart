import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/sync_settings.dart';
import 'package:managevity/services/cache_service.dart';
import 'package:managevity/services/calendar/sync_engine.dart';
import 'package:managevity/services/settings_service.dart';
import 'package:managevity/services/storage.dart';
import 'package:managevity/services/sync_lock_io.dart';

import '../fixtures/fixtures.dart';

// The real storage (IsolatedHive on disk), not the fakes: this is the layer the app and
// the background task share.
/// Takes the lock in an isolate of its own and holds it until the test gives the signal.
Future<void> _holdLock(SendPort ready) async {
  await withSyncLock(() async {
    final release = ReceivePort();
    ready.send(release.sendPort);
    final done = await release.first as SendPort;
    release.close();
    // Report only after releasing: the lock is released when this function returns.
    scheduleMicrotask(
      () => Future<void>.delayed(const Duration(milliseconds: 50), () => done.send(true)),
    );
  });
}

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('managevity_test_');
    await initStorage(path: dir.path);
  });
  tearDownAll(() => dir.delete(recursive: true));

  test('settings: location and sync survive a round trip through storage', () async {
    final settings = SettingsService();
    expect(await settings.getLocation(), isNull);
    await settings.setLocation(7, 'Downtown');
    expect(await settings.getLocation(), (7, 'Downtown'));

    final lastRun = DateTime(2026, 9, 21, 14, 5);
    await settings.setSync(
      SyncSettings(
        kind: SyncTargetKind.calDav,
        calendarId: 'cal',
        calendarName: 'Sport',
        reminderMinutes: 30,
        lastRun: lastRun,
      ),
    );
    final read = await settings.getSync();
    expect(
      (read.kind, read.calendarId, read.reminderMinutes, read.lastRun),
      (SyncTargetKind.calDav, 'cal', 30, lastRun),
    );

    await settings.clearLocation();
    expect(await settings.getLocation(), isNull);
  });

  test('lesson cache and sync index', () async {
    final cache = CacheService();
    final lesson = lessonFixture(id: 5, start: DateTime(2026, 9, 22, 19), status: 'Booked');
    await cache.saveLessons('booked:7', [lesson]);
    expect((await cache.loadLessons('booked:7')).single.toJson(), lesson.toJson());
    expect(await cache.loadLessons('does-not-exist'), isEmpty);

    final index = HiveSyncIndexStore();
    final entry = SyncIndexEntry(
      lessonId: 5,
      ref: 'https://x/5.ics',
      etag: '"1"',
      hash: 'h',
      startUtc: lesson.startUtc,
    );
    await index.save('calDav:cal', {5: entry});
    expect((await index.load('calDav:cal'))[5]!.toJson(), entry.toJson());
    expect(await index.load('other-target'), isEmpty);
  });

  test('the sync lock lets one through at a time and is free again afterwards', () async {
    final order = <String>[];
    final first = withSyncLock(() async {
      order.add('a starts');
      // While a holds the lock, b does not get it and skips its turn.
      final second = await withSyncLock(() async {
        order.add('b');
        return 'b';
      });
      expect(second, isNull);
      order.add('a done');
      return 'a';
    });
    expect(await first, 'a');
    expect(order, ['a starts', 'a done']);

    // Released: the next one simply gets in, also after an error in the action.
    await expectLater(withSyncLock<void>(() async => throw StateError('broken')), throwsStateError);
    expect(await withSyncLock(() async => 'c'), 'c');
  });

  test('a lock held by a dead isolate is taken over', () async {
    // A name with no living listener behind it: that is what a killed background task looks like.
    final dead = ReceivePort();
    IsolateNameServer.registerPortWithName(dead.sendPort, 'managevity.sync.lock');
    dead.close();
    expect(await withSyncLock(() async => 'taken over'), 'taken over');
  });

  test('a real second isolate holding the lock keeps us out', () async {
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_holdLock, ready.sendPort);
    final release = await ready.first as SendPort;

    expect(await withSyncLock(() async => 'us'), isNull);

    final done = ReceivePort();
    release.send(done.sendPort);
    await done.first;
    isolate.kill();
    expect(await withSyncLock(() async => 'us'), 'us');
  });
}
