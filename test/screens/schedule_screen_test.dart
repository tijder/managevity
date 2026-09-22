import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/models/lesson.dart';
import 'package:managevity/providers/lessons_provider.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/schedule_screen.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final noon = dayOf(DateTime.now()).add(const Duration(hours: 12));

  testWidgets("shows today's lessons with their status", (tester) async {
    final api = FakeSportivityApi(
      lessons: [
        lessonFixture(id: 1, description: 'Yoga', start: noon, status: 'Booked'),
        lessonFixture(id: 2, description: 'Spinning', start: noon, spots: 0, activity: 'Spinning'),
        lessonFixture(
          id: 3,
          description: 'Not until tomorrow',
          start: noon.add(const Duration(days: 1)),
        ),
      ],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();

    expect(find.text('Yoga'), findsWidgets);
    expect(find.text('Booked'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);
    expect(find.text('Not until tomorrow'), findsNothing);
  });

  testWidgets('a lesson nobody has booked yet shows all spots free, not "Full"', (tester) async {
    final api = FakeSportivityApi(
      lessons: [
        // Straight from JSON, as the server sends it: SpotsInt is the number of people going.
        for (final (id, going) in [(1, 0), (2, 18)])
          Lesson.tryFromJson({
            '_id': id,
            'Description': 'Lesson $id',
            'UTCStartTime': noon.toUtc().toIso8601String(),
            'UTCEndTime': noon.add(const Duration(hours: 1)).toUtc().toIso8601String(),
            'SpotsInt': going,
            'MaximumParticipants': 24,
            'Full': false,
          })!,
      ],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();

    expect(find.text('Full'), findsNothing);
    expect(find.text('24 spots free'), findsOneWidget);
    expect(find.text('6 spots free'), findsOneWidget);
  });

  testWidgets('filters by activity', (tester) async {
    final api = FakeSportivityApi(
      lessons: [
        lessonFixture(id: 1, description: 'Yin yoga', start: noon),
        lessonFixture(id: 2, description: 'Spinning 45', start: noon, activity: 'Spinning'),
      ],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Spinning'));
    await tester.pumpAndSettle();
    expect(find.text('Spinning 45'), findsOneWidget);
    expect(find.text('Yin yoga'), findsNothing);
  });

  testWidgets('empty day', (tester) async {
    await tester.pumpWidget(
      testApp(const _WithSession(child: ScheduleScreen()), api: FakeSportivityApi()),
    );
    await tester.pumpAndSettle();
    expect(find.text('No lessons on this day.'), findsOneWidget);
  });
}

/// The screens behind the guard count on a loaded session; in the app the router takes
/// care of that.
class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
