import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/services/calendar/caldav_target.dart';
import 'package:managevity/services/calendar/calendar_sync_target.dart';
import 'package:managevity/services/calendar/sync_engine.dart';

/// A minimal in-memory CalDAV server: PUT with If-Match / If-None-Match, DELETE.
class FakeDavServer implements HttpClientAdapter {
  final objects = <String, (String body, String etag)>{};
  var _rev = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? stream, Future<void>? _) async {
    final url = o.uri.toString();
    final current = objects[url];
    switch (o.method) {
      case 'PUT':
        if (o.headers['If-None-Match'] == '*' && current != null) return _reply(412);
        final ifMatch = o.headers['If-Match'];
        if (ifMatch != null && ifMatch != current?.$2) return _reply(412);
        final body = utf8.decode((await stream!.toList()).expand((c) => c).toList());
        final etag = '"${++_rev}"';
        objects[url] = (body, etag);
        return _reply(current == null ? 201 : 204, etag: etag);
      case 'DELETE':
        return _reply(objects.remove(url) == null ? 404 : 204);
    }
    return _reply(405);
  }

  ResponseBody _reply(int status, {String? etag}) => ResponseBody.fromString(
    '',
    status,
    headers: {
      if (etag != null) 'etag': [etag],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  const calendar = 'https://cloud.example.org/remote.php/dav/calendars/test/sport/';
  final now = DateTime.utc(2026, 9, 21, 12);
  final tomorrow = now.add(const Duration(days: 1));

  late FakeDavServer server;
  late SyncEngine phone, laptop;

  SyncEngine device() => SyncEngine(
    target: CalDavTarget(
      baseUrl: 'https://cloud.example.org/remote.php/dav/',
      username: 'test',
      password: 'x',
      dio: Dio()..httpClientAdapter = server,
    ),
    store: MemorySyncIndexStore(), // each device has its own index
    clock: () => now,
  );

  CalendarEvent lesson(int id, {String title = 'Yoga'}) => CalendarEvent(
    uid: lessonUid(id),
    title: title,
    startUtc: tomorrow,
    endUtc: tomorrow.add(const Duration(hours: 1)),
  );

  Future<SyncResult> sync(SyncEngine engine, Map<int, CalendarEvent> booked) =>
      engine.sync(calendarId: calendar, booked: booked, windowStart: now);

  setUp(() {
    server = FakeDavServer();
    phone = device();
    laptop = device();
  });

  test('the same lesson from two devices gives one event, not a duplicate', () async {
    await sync(phone, {1: lesson(1)});
    final second = await sync(laptop, {1: lesson(1)});
    expect(second.ok, isTrue);
    expect(server.objects, hasLength(1));
  });

  test('cancelling: one device deletes, the other does not trip over the 404', () async {
    await sync(phone, {1: lesson(1)});
    await sync(laptop, {1: lesson(1)});

    expect((await sync(laptop, {})).deleted, 1);
    expect(server.objects, isEmpty);

    final late = await sync(phone, {});
    expect(late.ok, isTrue);
    expect(server.objects, isEmpty);
  });

  test('a change made by one device is not reverted by the other', () async {
    await sync(phone, {1: lesson(1)});
    await sync(laptop, {1: lesson(1)});

    await sync(laptop, {1: lesson(1, title: 'Yoga (room 2)')});
    // The phone has a stale ETag; the lesson is the truth, so it writes the same new
    // content once more — the result stays correct.
    final result = await sync(phone, {1: lesson(1, title: 'Yoga (room 2)')});
    expect(result.ok, isTrue);
    expect(server.objects.values.single.$1, contains('SUMMARY:Yoga (room 2)'));
  });

  test('the gap: a lesson this device never saw is not cleaned up by it either', () async {
    await sync(phone, {1: lesson(1)});
    // Cancelled before the laptop ever synced: the laptop does not know it and therefore
    // leaves it alone. It only disappears at the phone's next sync.
    await sync(laptop, {});
    expect(server.objects, hasLength(1));
    await sync(phone, {});
    expect(server.objects, isEmpty);
  });
}
