import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/l10n/l10n.dart';
import 'package:managevity/widgets/async_view.dart';
import 'package:skeletonizer/skeletonizer.dart';

// Skeletonizer() is a factory that returns a private subclass; byType matches on the
// exact type and therefore does not find it.
final skeleton = find.byWidgetPredicate((w) => w is Skeletonizer);

void main() {
  Widget app(AsyncValue<List<String>> value, {List<String>? placeholder, VoidCallback? onTap}) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: AsyncView<List<String>>(
            value: value,
            onRetry: () {},
            placeholder: placeholder,
            builder: (items) => ListView(
              children: [for (final i in items) ListTile(title: Text(i), onTap: onTap)],
            ),
          ),
        ),
      );

  testWidgets('loading with a placeholder: the layout is there as a skeleton, without a spinner', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      app(const AsyncLoading(), placeholder: const ['fake one', 'fake two'], onTap: () => taps++),
    );
    // For the first quarter of a second nothing is shown yet: a fast load gives no flash.
    await tester.pump(const Duration(milliseconds: 100));
    expect(skeleton, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Not pumpAndSettle: the skeleton animates for as long as it is shown.
    await tester.pump(AsyncView.skeletonDelay);
    await tester.pump(const Duration(milliseconds: 300));

    expect(skeleton, findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Fake data cannot be tapped.
    await tester.tap(find.byType(ListTile).first, warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('loading without a placeholder: the spinner stays', (tester) async {
    await tester.pumpWidget(app(const AsyncLoading()));
    await tester.pump(AsyncView.skeletonDelay);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('content: no skeleton any more', (tester) async {
    await tester.pumpWidget(app(const AsyncData(['real']), placeholder: const ['fake']));
    await tester.pumpAndSettle();
    expect(skeleton, findsNothing);
    expect(find.text('real'), findsOneWidget);
  });

  testWidgets('refreshing: the old content stays, no skeleton and no spinner', (tester) async {
    final gate = Completer<List<String>>();
    var calls = 0;
    final provider = FutureProvider<List<String>>(
      (ref) => calls++ == 0 ? Future.value(['old']) : gate.future,
    );
    late WidgetRef captured;

    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return app(ref.watch(provider), placeholder: const ['fake']);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('old'), findsOneWidget);

    captured.invalidate(provider);
    await tester.pump();
    expect(find.text('old'), findsOneWidget);
    expect(skeleton, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete(['new']);
    await tester.pumpAndSettle();
    expect(find.text('new'), findsOneWidget);
  });

  testWidgets('error without earlier content: a message with a retry button', (tester) async {
    await tester.pumpWidget(
      app(AsyncError('broken', StackTrace.empty), placeholder: const ['fake']),
    );
    // No raw error text on screen, but a plain sentence and a way out.
    expect(find.text('broken'), findsNothing);
    expect(find.textContaining('unexpected'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
