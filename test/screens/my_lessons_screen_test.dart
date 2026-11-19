import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/my_lessons_screen.dart';
import 'package:managevity/utils/dates.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('a lesson of today that is over is no longer "upcoming"', (tester) async {
    final today = dayOf(DateTime.now());
    final api = FakeSportivityApi(
      lessons: [
        // Midnight to one o'clock: over at whatever time the tests run (bar the first hour).
        lessonFixture(id: 1, description: 'Night owl', start: today, status: 'Booked'),
        lessonFixture(
          id: 2,
          description: 'Tomorrow yoga',
          start: addDays(today, 1, hour: 19),
          status: 'Booked',
        ),
      ],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: MyLessonsScreen()), api: api));
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow yoga'), findsOneWidget);
    expect(find.text('Night owl'), findsNothing);
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
