import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/models/guest_pass.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/guests_screen.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<FakeSportivityApi> pump(WidgetTester tester, [FakeSportivityApi? api]) async {
    final fake = api ?? FakeSportivityApi();
    await tester.pumpWidget(testApp(const _WithSession(child: GuestsScreen()), api: fake));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('signing up a guest asks first, then shows them', (tester) async {
    final api = await pump(tester);
    expect(find.text('No guests signed up.'), findsOneWidget);

    await tester.tap(find.text('Sign up a guest'));
    await tester.pumpAndSettle();
    // Without a name nothing goes out.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign up a guest'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Sam Guest');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign up a guest'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sam Guest is signed up as your guest'), findsOneWidget);
    expect(api.guests, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign up a guest'));
    await tester.pumpAndSettle();
    expect(api.guests.single.name, 'Sam Guest');
    expect(find.text('Sam Guest'), findsOneWidget);
  });

  testWidgets('saying no to the question sends nothing', (tester) async {
    final api = FakeSportivityApi()..guests.add(const GuestPass(id: 1, name: 'Sam Guest'));
    await pump(tester, api);
    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(api.guests, hasLength(1));

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(api.guests, isEmpty);
  });

  testWidgets('without guest visits: the reason, and no button', (tester) async {
    final api = FakeSportivityApi()
      ..guestAllowed = const GuestAllowance(allowed: false, message: 'No duo membership.');
    await pump(tester, api);
    expect(find.text('No duo membership.'), findsOneWidget);
    expect(find.text('Sign up a guest'), findsNothing);
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
