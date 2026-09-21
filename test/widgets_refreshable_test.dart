import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/l10n/l10n.dart';
import 'package:managevity/services/sportivity_api.dart';
import 'package:managevity/utils/errors.dart';
import 'package:managevity/widgets/refreshable.dart';

void main() {
  Widget page(Future<void> Function() onRefresh) => Scaffold(
    appBar: AppBar(
      actions: [IconButton(icon: const Icon(Icons.star), onPressed: () {})],
    ),
    body: Refreshable(
      onRefresh: onRefresh,
      child: ListView(children: const [ListTile(title: Text('content'))]),
    ),
  );

  testWidgets('F5 refreshes and shows the indicator, even when the focus is elsewhere', (
    tester,
  ) async {
    final gate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: page(() {
          calls++;
          return gate.future;
        }),
      ),
    );

    // Move the focus to the app bar: with focus-bound shortcuts F5 no longer did anything here.
    await tester.tap(find.byIcon(Icons.star));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  testWidgets('Ctrl+R does the same; a bare R does not', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: page(() async => calls++)));

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();
    expect(calls, 0);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('only the visible page responds: not the hidden tab', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: IndexedStack(
          index: 0,
          children: [page(() async => calls.add('visible')), page(() async => calls.add('hidden'))],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(calls, ['visible']);
  });

  testWidgets('…and not the page that has another one on top of it', (tester) async {
    final calls = <String>[];
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: page(() async => calls.add('below'))),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page(() async => calls.add('above'))),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(calls, ['above']);
  });

  // Needs the app's localizations for the message.
  Widget localized(Widget home) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: home,
  );

  testWidgets('a failed refresh is reported instead of vanishing', (tester) async {
    await tester.pumpWidget(
      localized(page(() async => throw const SportivityException(AppError.network))),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.text('Refresh failed: No connection to the server.'), findsOneWidget);
    // The content that was there stays.
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('an unexpected error gets a plain sentence, not a stack-trace fragment', (
    tester,
  ) async {
    await tester.pumpWidget(localized(page(() async => throw StateError('No element'))));
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.textContaining('No element'), findsNothing);
    expect(find.textContaining('Something unexpected went wrong'), findsOneWidget);
  });
}
