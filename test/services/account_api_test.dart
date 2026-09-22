import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/guest_pass.dart';
import 'package:managevity/models/gym_extras.dart';
import 'package:managevity/models/membership.dart';
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

  group('add-ons', () {
    const addon = Addon(id: 4, description: 'Sauna');

    test('both steps send the same change; a warning is a refusal', () async {
      final client = api(
        (o, _) => json({'Response': 'Succes', 'Warning': false, 'Message': 'Per 1 oktober € 5,-'}),
      );
      expect(
        await client.requestAddonChange(addon, on: true, from: DateTime(2026, 10, 1)),
        'Per 1 oktober € 5,-',
      );
      await client.confirmAddonChange(addon, on: true, from: DateTime(2026, 10, 1));
      expect(sent.map((r) => r.$1.path), ['AddOn/TurnOnOff', 'AddOn/TurnOnOffConfirmation']);
      for (final (_, body) in sent) {
        expect(body, {'AddonID': 4, 'AddOnTurnOn': true, 'StartDate': '2026-10-01'});
      }

      final refusing = api(
        (_, _) => json({'Response': 'Succes', 'Warning': true, 'Message': 'Niet mogelijk'}),
      );
      await expectLater(
        refusing.requestAddonChange(addon, on: false, from: DateTime(2026, 10, 1)),
        refusedWith('Niet mogelijk'),
      );
    });
  });

  group('membership changes', () {
    const membership = Membership(id: 31, description: 'Unlimited');
    const reason = CancellationReason(id: 146464, description: 'Other gym');

    test('each sends exactly the membership, the dates and the reason', () async {
      final client = api((_, _) => json({'Response': 'Verzoek ontvangen', 'Warning': false}));
      await client.freezeMembership(
        membership,
        reason: 'Holiday',
        from: DateTime(2026, 10, 1),
        until: DateTime(2026, 10, 31),
      );
      await client.cancelMembership(membership, from: DateTime(2027, 1, 1), reason: reason);
      await client.withdrawMembership(membership, from: DateTime(2026, 9, 22), reason: reason);
      expect(sent.map((r) => r.$1.path), [
        'ChangeMembership/Freeze',
        'ChangeMembership/Cancel',
        'ChangeMembership/RightOfWithdrawal',
      ]);
      expect(sent.map((r) => r.$2), [
        {
          'MembershipID': 31,
          'Reason': 'Holiday',
          'StartDate': '2026-10-01',
          'FreezeTillDate': '2026-10-31',
        },
        {'MembershipID': 31, 'StartDate': '2027-01-01', 'TerminationId': 146464},
        {'MembershipID': 31, 'StartDate': '2026-09-22', 'TerminationId': 146464},
      ]);
    });

    test('a warning is a refusal, with the reason', () async {
      final client = api(
        (_, _) => json({'Response': 'Opzeggen kan pas na 12 maanden', 'Warning': true}),
      );
      await expectLater(
        client.cancelMembership(membership, from: DateTime(2027, 1, 1), reason: reason),
        refusedWith('Opzeggen kan pas na 12 maanden'),
      );
    });

    test('the flags from the real data are read', () {
      final m = Membership.tryFromJson({
        'MembershipID': 1,
        'AllowFreeze': false,
        'AllowCancel': true,
        'CoolingOff': false,
        'CanConvert': true,
        'OnlyConvertEndContract': false,
        'Terminated': false,
      })!;
      expect(
        (m.allowFreeze, m.allowCancel, m.coolingOff, m.canConvert),
        (false, true, false, true),
      );
    });
  });

  group('the offer (read-only)', () {
    test('offers, conditions and first costs as the real server shapes them', () async {
      final client = api(
        (o, _) => json(switch (o.path) {
          'MembershipDefinition/MembershipDefinitions' => {
            'Response': 'Succes',
            'MembershipDefinitions': [
              {
                'MembershipDefinitionId': 67523,
                'AmountString': '€ 54,50 per maand',
                'IsAction': false,
                'Description': 'Plan ONE',
                'ActionInfo': '',
                'PaymentMethodString': 'Factuur',
              },
            ],
          },
          'MembershipDefinition/Conditions' => {
            'Response': 'Succes',
            'IBANMandatory': true,
            'Conditions': [
              {
                'HasBase64': true,
                'ConditionType': 'AVG',
                'Text': 'Ik ga akkoord',
                'Mandatory': true,
                'LinkText': 'privacy voorwaarden*',
              },
            ],
          },
          _ => {
            'FirstCostAmount': 0,
            'FirstCostString': 'Kosten abonnement 1e periode tot 01-10-2026',
            'TotalAmountString': '€ 29,75',
            'TotalAmount': 29.75,
            'Response': 'Succes',
            'Deposits': [
              {'Description': 'Inschrijfkosten', 'AmountString': '€ 29,75', 'Amount': 29.75},
            ],
            'FirstCostsAmountString': '€ 0,00',
          },
        }),
      );
      final offer = (await client.membershipOffers(7, 'nl')).single;
      expect(
        (offer.id, offer.amount, offer.paymentMethod),
        (67523, '€ 54,50 per maand', 'Factuur'),
      );
      final conditions = await client.offerConditions(7, 'nl', offer.id);
      expect(conditions.ibanRequired, isTrue);
      expect(
        (conditions.conditions.single.type, conditions.conditions.single.hasPdf),
        ('AVG', true),
      );
      final costs = await client.firstCosts(7, 'nl', offer, start: DateTime(2026, 9, 22));
      expect(
        (costs.firstCosts, costs.total, costs.deposits.single.amount),
        ('€ 0,00', '€ 29,75', '€ 29,75'),
      );
      expect(sent.last.$1.queryParameters['StartDate'], '2026-09-22');
      // Only GETs: nothing in the offer screen can take out a membership.
      expect(sent.every((r) => r.$1.method == 'GET'), isTrue);
    });

    test('a condition PDF comes as Base64', () async {
      final client = api((_, _) => json({'Response': 'Succes', 'Base64': 'JVBERi0='}));
      expect(await client.conditionPdf(7, 'nl', 'AVG'), [37, 80, 68, 70, 45]);
      expect(sent.single.$1.queryParameters['ConditionType'], 'AVG');
    });
  });

  group('what the gym shows in its own app', () {
    test('a button needs a label and a web address, or it is not shown', () {
      expect(
        GymButton.tryFromJson({'Text': 'Timetable', 'Url': 'https://example.org/t'})?.uri.host,
        'example.org',
      );
      expect(GymButton.tryFromJson({'Text': 'Timetable'}), isNull);
      expect(GymButton.tryFromJson({'Text': 'X', 'Url': 'javascript:alert(1)'}), isNull);
    });

    test('the logo is asked for without posing as the official app', () async {
      final client = api(
        (_, _) => json({
          'Response': 'Succes',
          'Logos': [
            {'Base64': 'iVBORw0KGgo='},
          ],
        }),
      );
      final logo = await client.gymLogo();
      expect(logo?.bytes, isNotEmpty);
      expect(
        sent.single.$1.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('bundleidentifier')),
      );
    });

    test('no logos: no logo', () async {
      final client = api((_, _) => json({'Response': 'No logo'}));
      expect(await client.gymLogo(), isNull);
    });
  });
}
