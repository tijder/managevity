import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
