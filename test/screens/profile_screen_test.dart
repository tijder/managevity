import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/profile_screen.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

void main() {
  Future<FakeSportivityApi> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeSportivityApi();
    await tester.pumpWidget(testApp(const _WithSession(child: ProfileScreen()), api: api));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('the address is looked up from postcode and house number', (tester) async {
    await pump(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Postcode'), '1234 AB');
    await tester.enterText(find.widgetWithText(TextField, 'House number'), '12');
    await tester.tap(find.text('Look up address'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Station Road'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Exampleton'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Postcode'), '0000 XX');
    await tester.tap(find.text('Look up address'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No address found'), findsOneWidget);
  });

  testWidgets('an opt-in applies at once and can be undone', (tester) async {
    final api = await pump(tester);
    expect(api.optInSettings.whatsapp, isFalse);
    await tester.tap(find.widgetWithText(SwitchListTile, 'WhatsApp'));
    await tester.pumpAndSettle();
    expect(api.optInSettings.whatsapp, isTrue);
    expect(api.optInSettings.email, isTrue, reason: 'the other flags go along unchanged');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(api.optInSettings.whatsapp, isFalse);
  });

  testWidgets('the language the gym writes in', (tester) async {
    final api = await pump(tester);
    expect(find.text('Dutch'), findsOneWidget);
    await tester.tap(find.text('Dutch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(api.languages, ['en_GB']);
    expect(find.textContaining('write to you in English'), findsOneWidget);
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
