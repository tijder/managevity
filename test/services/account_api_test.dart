import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/guest_pass.dart';
import 'package:managevity/models/profile_settings.dart';
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

  group('profile', () {
    test('opt-in: all three flags go along, so one switch does not reset the others', () async {
      final client = api((_, _) => json({'Response': 'Succes'}));
      await client.setOptIn(7, const OptInSettings(email: true, whatsapp: true));
      expect(sent.single.$2, {
        'OptIn': true,
        'LocationId': 7,
        'OptInCalls': false,
        'OptInWhatsapp': true,
      });
    });

    test('address lookup: found, and not found', () async {
      var found = true;
      final client = api(
        (o, _) => json({
          'Response': 'Succes',
          'Address': found ? 'Station Road' : null,
          'City': found ? 'Exampleton' : null,
          'Zipcode': o.queryParameters['ZipCode'],
        }),
      );
      final hit = await client.lookupAddress(7, zipCode: '1234 AB', houseNumber: 12);
      expect((hit?.street, hit?.city), ('Station Road', 'Exampleton'));
      expect(sent.single.$1.queryParameters, {
        'LocationId': 7,
        'ZipCode': '1234 AB',
        'HouseNumber': 12,
      });
      found = false;
      expect(await client.lookupAddress(7, zipCode: '0000 XX', houseNumber: 1), isNull);
    });

    test('language goes as the locale code', () async {
      final client = api((_, _) => json({'Response': 'Succes'}));
      await client.setLanguage(7, 'en_GB');
      expect(sent.single.$2, {'LocationId': 7, 'Language': 'en_GB'});
    });
  });

  group('payments', () {
    Map<String, Object?> page(String link) => {
      'Response': 'Succes',
      'Warning': false,
      'Sisow': {'SisowLink': link},
    };

    test('paying asks for a page, with DeviceType Web, and returns the link', () async {
      final client = api((_, _) => json(page('https://pay.example.org/abc')));
      expect(await client.paymentLink(7), Uri.parse('https://pay.example.org/abc'));
      expect(sent.single.$1.path, 'Payment/GetLink');
      expect(sent.single.$1.queryParameters, {'LocationId': 7, 'DeviceType': 'Web'});
    });

    test('topping up sends the amount, to the sport-credit variant where needed', () async {
      final client = api((_, _) => json(page('https://pay.example.org/abc')));
      await client.creditLink(7, 20);
      await client.creditLink(7, 5, sportCredits: true);
      expect(sent.map((r) => r.$1.path), [
        'Payment/GetCreditLink',
        'Payment/GetCreditLinkSportCredit',
      ]);
      expect(sent.first.$1.queryParameters['Amount'], 20);
    });

    test('a refusal, no link, or a link that is not a web page: an error', () async {
      for (final body in [
        {'Response': 'Geen openstaand bedrag', 'Warning': true},
        {'Response': 'Succes', 'Warning': false},
        page('javascript:alert(1)'),
      ]) {
        final client = api((_, _) => json(body));
        await expectLater(client.paymentLink(7), throwsA(isA<SportivityException>()));
      }
    });

    test('credit options: the label and the number that goes back', () async {
      final client = api(
        (_, _) => json({
          'Response': 'Succes',
          'CreditOptions': [
            {'Amount': '€10', 'Info': '', 'OriginalAmount': 10},
          ],
        }),
      );
      final option = (await client.creditOptions(7)).single;
      expect((option.label, option.amount), ('€10', 10));
    });
  });
}
