import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/services/calendar/calendar_sync_target.dart';
import 'package:managevity/services/calendar/caldav_target.dart';

typedef Handler = ResponseBody Function(RequestOptions options, String body);

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = requestStream == null
        ? <int>[]
        : (await requestStream.toList()).expand((c) => c).toList();
    return handler(options, utf8.decode(bytes));
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody reply(int status, [String body = '', Map<String, List<String>>? headers]) =>
    ResponseBody.fromString(body, status, headers: headers ?? {});

// The way Nextcloud answers (abridged), with a made-up user.
const _principal = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:"><d:response><d:href>/remote.php/dav/</d:href><d:propstat><d:prop>
<d:current-user-principal><d:href>/remote.php/dav/principals/users/test/</d:href></d:current-user-principal>
</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>''';

const _home = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav"><d:response>
<d:href>/remote.php/dav/principals/users/test/</d:href><d:propstat><d:prop>
<cal:calendar-home-set><d:href>/remote.php/dav/calendars/test/</d:href></cal:calendar-home-set>
</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response></d:multistatus>''';

const _calendars = '''<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:x1="http://apple.com/ns/ical/">
<d:response><d:href>/remote.php/dav/calendars/test/</d:href><d:propstat><d:prop>
  <d:resourcetype><d:collection/></d:resourcetype></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
<d:response><d:href>/remote.php/dav/calendars/test/sport/</d:href><d:propstat><d:prop>
  <d:resourcetype><d:collection/><cal:calendar/></d:resourcetype><d:displayname>Sport</d:displayname>
  <x1:calendar-color>#0082C9</x1:calendar-color>
  <cal:supported-calendar-component-set><cal:comp name="VEVENT"/></cal:supported-calendar-component-set>
  <d:current-user-privilege-set><d:privilege><d:read/></d:privilege><d:privilege><d:write/></d:privilege></d:current-user-privilege-set>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
<d:response><d:href>/remote.php/dav/calendars/test/tasks/</d:href><d:propstat><d:prop>
  <d:resourcetype><d:collection/><cal:calendar/></d:resourcetype><d:displayname>Tasks</d:displayname>
  <cal:supported-calendar-component-set><cal:comp name="VTODO"/></cal:supported-calendar-component-set>
  <d:current-user-privilege-set><d:privilege><d:write/></d:privilege></d:current-user-privilege-set>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
<d:response><d:href>/remote.php/dav/calendars/test/shared/</d:href><d:propstat><d:prop>
  <d:resourcetype><d:collection/><cal:calendar/></d:resourcetype><d:displayname>Read only</d:displayname>
  <cal:supported-calendar-component-set><cal:comp name="VEVENT"/></cal:supported-calendar-component-set>
  <d:current-user-privilege-set><d:privilege><d:read/></d:privilege></d:current-user-privilege-set>
  </d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>
</d:multistatus>''';

void main() {
  final event = CalendarEvent(
    uid: 'lesson-7@managevity.g4d.nl',
    title: 'Spinning',
    startUtc: DateTime.utc(2026, 9, 22, 18),
    endUtc: DateTime.utc(2026, 9, 22, 19),
  );
  const calendar = 'https://cloud.example.org/remote.php/dav/calendars/test/sport/';

  (CalDavTarget, FakeAdapter) build(
    Handler handler, {
    String base = 'https://cloud.example.org/remote.php/dav/',
  }) {
    final adapter = FakeAdapter(handler);
    final dio = Dio()..httpClientAdapter = adapter;
    return (CalDavTarget(baseUrl: base, username: 'test', password: 'secret', dio: dio), adapter);
  }

  test('discovers only writable VEVENT calendars', () async {
    final (target, adapter) = build(
      (o, _) => switch (o.uri.path) {
        '/remote.php/dav/' => reply(207, _principal),
        '/remote.php/dav/principals/users/test/' => reply(207, _home),
        '/remote.php/dav/calendars/test/' => reply(207, _calendars),
        _ => reply(404),
      },
    );

    final calendars = await target.listCalendars();
    expect(calendars.map((c) => c.name), ['Sport']);
    expect(calendars.single.id, calendar);
    expect(calendars.single.color, '#0082C9');
    expect(adapter.requests.every((r) => r.method == 'PROPFIND'), isTrue);
    expect(adapter.requests.last.headers['Depth'], '1');
    expect(
      adapter.requests.first.headers['Authorization'],
      'Basic ${base64Encode(utf8.encode('test:secret'))}',
    );
  });

  test('a bare server URL falls back to /remote.php/dav/', () async {
    final (target, adapter) = build(
      (o, _) => switch (o.uri.path) {
        '/' => reply(405),
        '/.well-known/caldav' => reply(301),
        '/remote.php/dav/' => reply(207, _principal),
        '/remote.php/dav/principals/users/test/' => reply(207, _home),
        '/remote.php/dav/calendars/test/' => reply(207, _calendars),
        _ => reply(404),
      },
      base: 'https://cloud.example.org',
    );
    expect(await target.listCalendars(), hasLength(1));
    expect(adapter.requests.map((r) => r.uri.path).take(3), [
      '/',
      '/.well-known/caldav',
      '/remote.php/dav/',
    ]);
  });

  test('a wrong password gives a clear error', () async {
    final (target, _) = build((_, _) => reply(401));
    expect(
      target.listCalendars(),
      throwsA(isA<CalendarSyncException>().having((e) => e.statusCode, 'status', 401)),
    );
  });

  test('new event: PUT with If-None-Match and the UID as the file name', () async {
    final (target, adapter) = build((o, body) {
      expect(body, contains('UID:lesson-7@managevity.g4d.nl'));
      return reply(201, '', {
        'etag': ['"abc"'],
      });
    });
    final written = await target.upsert(calendar, event);
    expect(written.ref, '${calendar}lesson-7_managevity.g4d.nl.ics');
    expect(written.etag, '"abc"');
    expect(adapter.requests.single.headers['If-None-Match'], '*');
    expect(adapter.requests.single.headers['Content-Type'], startsWith('text/calendar'));
  });

  test('existing event: If-Match, and on a 412 again without a precondition', () async {
    final (target, adapter) = build(
      (o, _) => o.headers.containsKey('If-Match')
          ? reply(412)
          : reply(204, '', {
              'etag': ['"new"'],
            }),
    );
    final written = await target.upsert(
      calendar,
      event,
      existing: const WrittenEvent(ref: '${calendar}x.ics', etag: '"old"'),
    );
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.headers['If-Match'], '"old"');
    expect(adapter.requests.last.uri.toString(), '${calendar}x.ics');
    expect(written.etag, '"new"');
  });

  test('a server error on PUT becomes an exception', () async {
    final (target, _) = build((_, _) => reply(507));
    expect(target.upsert(calendar, event), throwsA(isA<CalendarSyncException>()));
  });

  test('delete: a 404 is not an error, a 500 is', () async {
    const existing = WrittenEvent(ref: '${calendar}x.ics');
    final (gone, _) = build((_, _) => reply(404));
    await gone.delete(calendar, existing);

    final (broken, _) = build((_, _) => reply(500));
    expect(broken.delete(calendar, existing), throwsA(isA<CalendarSyncException>()));
  });
}
