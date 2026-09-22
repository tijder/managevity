import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/guest_pass.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/services/sportivity_api.dart';
import 'package:managevity/utils/errors.dart';

import 'sportivity_api_test.dart' show FakeAdapter, json;

/// The account side of the API: guests, profile, payments, add-ons, membership changes and
/// the offer. What matters most here is what goes *out*: a write must carry exactly what
/// the user confirmed, and nothing may be sent that was not confirmed.
void main() {
  late List<(RequestOptions, Object?)> sent;

  SportivityApi api(ResponseBody Function(RequestOptions o, Object? body) handler) {
    sent = [];
    final adapter = FakeAdapter((o, body) {
      sent.add((o, body));
      return handler(o, body);
    });
    return SportivityApi(dio: Dio()..httpClientAdapter = adapter)
      ..session = const Session(token: 't');
  }

  Matcher refusedWith(String message) => throwsA(
    isA<SportivityException>()
        .having((e) => e.code, 'code', AppError.requestFailed)
        .having((e) => e.serverMessage, 'server message', message),
  );

  group('guests', () {
    test('signing up sends the guest, with the date as yyyy-MM-dd', () async {
      final client = api((_, _) => json({'Succes': true, 'Response': 'Aangemeld'}));
      final message = await client.addGuest(
        7,
        NewGuest(name: 'Sam Guest', email: 'sam@example.org', visitDate: DateTime(2026, 10, 3)),
      );
      expect(message, 'Aangemeld');
      expect(sent.single.$1.method, 'POST');
      expect(sent.single.$1.path, 'TogetherEntrance');
      expect(sent.single.$2, {
        'FullnameGuest': 'Sam Guest',
        'EmailGuest': 'sam@example.org',
        'MobilePhoneGuest': '',
        'DateVisitGuest': '2026-10-03',
        'LocationId': 7,
        'Delete': false,
        'TogetherEntranceID': 0,
      });
    });

    test('removing sends Delete with the id', () async {
      final client = api((_, _) => json({'Succes': true, 'Response': 'OK'}));
      await client.deleteGuest(7, const GuestPass(id: 12, name: 'Sam Guest'));
      final body = sent.single.$2! as Map;
      expect((body['Delete'], body['TogetherEntranceID']), (true, 12));
    });

    test('a refusal (HTTP 200, Succes false) becomes an error with the server text', () async {
      final client = api((_, _) => json({'Succes': false, 'Response': 'Geen duobezoeken over'}));
      await expectLater(
        client.addGuest(7, NewGuest(name: 'Sam', visitDate: DateTime(2026, 10, 3))),
        refusedWith('Geen duobezoeken over'),
      );
    });

    test('CheckMembership with a warning means: no guests now, and why', () async {
      final client = api(
        (_, _) => json({'Response': 'Geen actief duo abonnement.', 'Warning': true}),
      );
      final allowance = await client.guestAllowance(7);
      expect(allowance.allowed, isFalse);
      expect(allowance.message, 'Geen actief duo abonnement.');
    });
  });
}
