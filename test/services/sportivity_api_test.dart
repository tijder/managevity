import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/services/sportivity_api.dart';
import 'package:managevity/utils/errors.dart';

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final ResponseBody Function(RequestOptions options, Object? body) handler;
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
    return handler(options, bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes)));
  }

  @override
  void close({bool force = false}) {}
}

// The server (almost) always answers with HTTP 200 and puts the outcome in the body.
ResponseBody json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

(SportivityApi, FakeAdapter) build(ResponseBody Function(RequestOptions, Object?) handler) {
  final adapter = FakeAdapter(handler);
  return (SportivityApi(dio: Dio()..httpClientAdapter = adapter), adapter);
}

void main() {
  group('login', () {
    test('picks the Authorization form the server does not reject', () async {
      final (api, adapter) = build((o, body) {
        if (o.path == 'Login') return json({'Token': 'tok', 'HttpStatusCode': 200});
        // This server wants Bearer; a bare token gives the familiar 200-with-error.
        return o.headers['Authorization'] == 'Bearer tok'
            ? json({'Response': 'OK', 'Customer': {}})
            : json({'Response': 'Wrong token'});
      });
      final session = await api.login('u', 'p');
      expect(session.scheme, AuthScheme.bearer);
      expect(api.session?.headerValue, 'Bearer tok');
      expect(adapter.requests.first.headers['Accept'], 'application/json');
      expect(
        adapter.requests.first.uri.toString(),
        'https://www.sportivity.com/SportivityAppV3/Login',
      );
    });

    test('wrong password: HTTP 200 with HttpStatusCode 401 becomes an exception', () async {
      final (api, _) = build(
        (_, _) => json({'HttpStatusCode': 401, 'Message': 'Inloggegevens onjuist'}),
      );
      await expectLater(
        api.login('u', 'wrong'),
        throwsA(
          isA<SportivityException>()
              .having((e) => e.code, 'code', AppError.loginFailed)
              .having((e) => e.serverMessage, 'server message', 'Inloggegevens onjuist')
              .having((e) => e.statusCode, 'status', 401),
        ),
      );
      expect(api.session, isNull);
    });
  });

  group('session', () {
    test('"Wrong token" → sign in again once and repeat the call', () async {
      var renewals = 0;
      final (api, adapter) = build(
        (o, _) => o.headers['Authorization'] == 'new'
            ? json({
                'Response': 'OK',
                'Locationss': [
                  {'LocationId': 7, 'NameLocation': 'Downtown'},
                ],
              })
            : json({'Response': 'Wrong token'}),
      );
      api.session = const Session(token: 'old');
      api.onSessionExpired = () async {
        renewals++;
        return const Session(token: 'new');
      };

      final locations = await api.locations();
      expect(locations.single.name, 'Downtown');
      expect(renewals, 1);
      expect(adapter.requests, hasLength(2));
    });

    test('if renewing fails: a 401 and no endless loop', () async {
      final (api, adapter) = build((_, _) => json({'Response': 'Wrong token'}));
      api.session = const Session(token: 'old');
      api.onSessionExpired = () async => const Session(token: 'wrong too');
      await expectLater(
        api.locations(),
        throwsA(isA<SportivityException>().having((e) => e.isUnauthorized, '401', isTrue)),
      );
      expect(adapter.requests, hasLength(2));
    });

    test('without a session nothing goes out', () async {
      final (api, adapter) = build((_, _) => json({}));
      await expectLater(api.locations(), throwsA(isA<SportivityException>()));
      expect(adapter.requests, isEmpty);
    });
  });

  group('locations', () {
    test('nothing without a LocationId: the memberships supply the first location', () async {
      final asked = <Object?>[];
      final (api, _) = build((o, _) {
        if (o.path == 'UserContent/CustomerMemberships') {
          return json({
            'Response': 'OK',
            'Memberships': [
              {'MembershipID': 1, 'LocationId': 7, 'LocationName': 'Downtown'},
            ],
          });
        }
        asked.add(o.queryParameters['LocationId']);
        return o.queryParameters['LocationId'] == 7
            ? json({
                'Response': 'OK',
                'Locationss': [
                  {'LocationId': 7, 'NameLocation': 'Downtown'},
                  {'LocationId': 8, 'NameLocation': 'North'},
                ],
              })
            : json({'Response': 'OK', 'Locationss': []});
      });
      api.session = const Session(token: 't');
      final locations = await api.locations();
      expect(asked, [null, 7]);
      expect(locations.map((l) => l.name), ['Downtown', 'North']);
    });

    test('if the company returns nothing: the location of the membership itself', () async {
      final (api, _) = build(
        (o, _) => o.path == 'UserContent/CustomerMemberships'
            ? json({
                'Memberships': [
                  {'MembershipID': 1, 'LocationId': 7, 'LocationName': 'Downtown'},
                ],
              })
            : json({'Locationss': []}),
      );
      api.session = const Session(token: 't');
      expect((await api.locations()).single.id, 7);
    });

    test('no location anywhere: the error mentions what the server said', () async {
      final (api, _) = build((_, _) => json({'Response': 'No access'}));
      api.session = const Session(token: 't');
      await expectLater(
        api.locations(),
        throwsA(
          isA<SportivityException>()
              .having((e) => e.code, 'code', AppError.noLocations)
              .having((e) => e.serverMessage, 'server message', contains('No access')),
        ),
      );
    });
  });

  test('invoices: requests all invoices, not only the unpaid ones', () async {
    final (api, adapter) = build(
      (_, _) => json({
        'Invoices': [
          {
            'InvoiceID': 3,
            'InvoiceNumber': '2026-003',
            'InvoiceStatus': 'Paid',
            'AmountAsString': '€ 29,95',
          },
        ],
      }),
    );
    api.session = const Session(token: 't');
    final invoices = await api.invoices(7);
    expect(adapter.requests.single.queryParameters['BooleanDefaultFalse'], isTrue);
    expect(invoices.single.number, '2026-003');
  });

  group('lessons', () {
    SportivityApi ready(ResponseBody Function(RequestOptions, Object?) handler) =>
        build(handler).$1..session = const Session(token: 't');

    test('schedule: the rich variant wins over the thin one, sorted by time', () async {
      final api = ready((o, _) {
        expect(o.queryParameters['LocationId'], 7);
        expect(o.queryParameters['StartDate'], '2026-09-22');
        return json({
          'Response': 'OK',
          'LessonIdsLists': [
            {
              '_id': 2,
              'Description': 'Yoga',
              'UTCStartTime': '2026-09-22T18:00:00',
              'UTCEndTime': '2026-09-22T19:00:00',
            },
            {
              '_id': 1,
              'Description': 'Spinning',
              'UTCStartTime': '2026-09-22T07:00:00Z',
              'UTCEndTime': '2026-09-22T08:00:00Z',
            },
          ],
          'LessonDefinitions': [
            {
              '_id': 2,
              'Description': 'Yoga',
              'Trainer': 'Anna',
              'UTCStartTime': '2026-09-22T18:00:00',
              'UTCEndTime': '2026-09-22T19:00:00',
            },
          ],
        });
      });
      final lessons = await api.schedule(7, DateTime(2026, 9, 22), DateTime(2026, 9, 23));
      expect(lessons.map((l) => l.id), [1, 2]);
      expect(lessons.last.trainer, 'Anna');
      // Without a zone designator a UTC… field is still UTC.
      expect(lessons.last.startUtc, DateTime.utc(2026, 9, 22, 18));
    });

    test('booking sends BuyLesson=false unless explicitly asked', () async {
      Object? sent;
      final api = ready((_, body) {
        sent = body;
        return json({
          'Succes': false,
          'ShowFinancialPopup': true,
          'AmountAsString': '€ 7,50',
          'LessonId': 5,
          'UTCStartTime': '2026-09-22T18:00:00Z',
          'UTCEndTime': '2026-09-22T19:00:00Z',
        });
      });
      final result = await api.joinLesson(5, 7);
      expect(sent, {'LessonId': 5, 'LocationId': '7', 'BuyLesson': false});
      expect(result.success, isFalse);
      expect(result.needsPayment, isTrue);
      expect(result.lesson?.amount, '€ 7,50');
    });

    test('a response that is not JSON becomes a clean error and not a crash', () async {
      final api = ready((_, _) => ResponseBody.fromString('<html>502</html>', 502));
      await expectLater(
        api.lesson(1),
        throwsA(isA<SportivityException>().having((e) => e.statusCode, 'status', 502)),
      );
    });
  });
}
