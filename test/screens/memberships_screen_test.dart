import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/models/membership.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/memberships_screen.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<(FakeSportivityApi, List<Uri>)> pump(WidgetTester tester, [FakeSportivityApi? api]) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = api ?? FakeSportivityApi();
    final opened = <Uri>[];
    await tester.pumpWidget(
      testApp(
        const _WithSession(child: MembershipsScreen()),
        api: fake,
        opened: opened,
      ),
    );
    await tester.pumpAndSettle();
    return (fake, opened);
  }

  testWidgets('topping up: choose, confirm the amount, then the payment page', (tester) async {
    final (api, opened) = await pump(tester);
    await tester.tap(find.text('Top up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('€20'));
    await tester.pumpAndSettle();
    expect(find.text('You top up your credit by €20.'), findsOneWidget);
    expect(api.paymentRequests, isEmpty);

    await tester.tap(find.text('To the payment page'));
    await tester.pumpAndSettle();
    expect(api.paymentRequests, [('credit', 20)]);
    expect(opened, [FakeSportivityApi.paymentPage]);
  });

  testWidgets('an add-on is switched only after both questions', (tester) async {
    final api = FakeSportivityApi()
      ..addonList = [
        const Addon(id: 2, description: 'Sports drink', price: '€ 4.00'),
        const Addon(id: 3, description: 'Insurance', mandatory: true, on: true),
      ];
    await pump(tester, api);
    expect(find.text('Required'), findsOneWidget, reason: 'a required add-on has no switch');
    expect(find.byType(Switch), findsOneWidget);

    Future<void> startSwitch() async {
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // the date: today
      await tester.pumpAndSettle();
    }

    // No at the first question: nothing goes out.
    await startSwitch();
    expect(find.textContaining('Sports drink is turned on from'), findsOneWidget);
    expect(find.text('Price: € 4.00'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(api.addonCalls, isEmpty);

    // No at the server's terms: asked, not carried out.
    await startSwitch();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('From then on you pay € 4.00 extra.'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(api.addonCalls, [('request', 2, true)]);

    // Yes to both.
    await startSwitch();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(api.addonCalls.last, ('confirm', 2, true));
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('only the changes the server allows are offered', (tester) async {
    final api = FakeSportivityApi()
      ..membershipList = [const Membership(id: 1, description: 'Unlimited', allowFreeze: true)];
    await pump(tester, api);
    expect(find.text('Freeze'), findsOneWidget);
    expect(find.text('Cancel membership'), findsNothing);
    expect(find.text('Withdraw'), findsNothing);
  });

  testWidgets('cancelling: a reason, then two questions, then the request', (tester) async {
    final api = FakeSportivityApi()
      ..membershipList = [const Membership(id: 1, description: 'Unlimited', allowCancel: true)];
    await pump(tester, api);
    await tester.tap(find.text('Cancel membership'));
    await tester.pumpAndSettle();

    // Without a reason it does not go further.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a reason'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<CancellationReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Too expensive').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.textContaining('You cancel Unlimited as of'), findsOneWidget);
    expect(find.text('Reason: Too expensive'), findsOneWidget);
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    // The second question; no to it stops everything.
    expect(find.text('Are you sure?'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(api.membershipChanges, isEmpty);

    await tester.tap(find.text('Cancel membership'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<CancellationReason>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Too expensive').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(api.membershipChanges, [('cancel', 1, 2)]);
  });

  testWidgets('freezing asks once, with the dates', (tester) async {
    final api = FakeSportivityApi()
      ..membershipList = [const Membership(id: 1, description: 'Unlimited', allowFreeze: true)];
    await pump(tester, api);
    await tester.tap(find.text('Freeze'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Reason'), 'Holiday');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unlimited is frozen from'), findsOneWidget);
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsNothing);
    expect(api.membershipChanges, [('freeze', 1, 'Holiday')]);
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
