import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/offers_screen.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

void main() {
  Future<FakeSportivityApi> pump(WidgetTester tester, {int? upgradeFrom}) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeSportivityApi();
    await tester.pumpWidget(
      testApp(
        _WithSession(child: OffersScreen(upgradeFrom: upgradeFrom)),
        api: api,
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('the offer, and what starting costs when opened', (tester) async {
    final api = await pump(tester);
    expect(find.text('Off-peak'), findsOneWidget);
    expect(find.text('Promotion'), findsOneWidget);
    expect(find.textContaining('goes through your gym'), findsOneWidget);
    // Nothing behind an offer is fetched until it is opened.
    expect(find.text('Registration fee'), findsNothing);

    await tester.tap(find.text('Off-peak'));
    await tester.pumpAndSettle();
    expect(find.text('Registration fee'), findsOneWidget);
    expect(find.text('€ 37.40'), findsOneWidget);
    expect(find.text('A bank account (IBAN) is required.'), findsOneWidget);

    await tester.tap(find.text('general terms'));
    await tester.pumpAndSettle();
    expect(api.pdfsRequested, ['GeneralTerms']);
  });

  testWidgets('switching: only what the membership can switch to', (tester) async {
    await pump(tester, upgradeFrom: 1);
    expect(find.text('Switch membership'), findsOneWidget);
    expect(find.text('Off-peak'), findsNothing);
    expect(find.text('Unlimited'), findsOneWidget);
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
