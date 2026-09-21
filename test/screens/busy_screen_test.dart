import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/models/heatmap.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/busy_screen.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

class _Api extends FakeSportivityApi {
  @override
  Future<List<HeatmapCell>> heatmapDay(int locationId, DateTime day) async => const [];

  // Like the real API: seven days, three parts of the day each.
  @override
  Future<List<HeatmapCell>> heatmapWeek(int locationId) async => [
    for (var day = 1; day <= 7; day++)
      for (var part = 1; part <= 3; part++)
        HeatmapCell(day: day, hour: part, value: day == 7 && part == 1 ? 100 : 10.0 * part),
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('week overview: days × parts of the day with readable labels', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(const _WithSession(child: BusyScreen()), api: _Api()));
    await tester.pumpAndSettle();

    for (final text in ['Morning', 'Afternoon', 'Evening', 'Monday', 'Sunday']) {
      expect(find.text(text), findsOneWidget);
    }
    // Only Sunday morning reaches the maximum; the rest is 10–30% of it.
    expect(find.text('Busy'), findsOneWidget);
    expect(find.text('Quiet'), findsNWidgets(20));
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
