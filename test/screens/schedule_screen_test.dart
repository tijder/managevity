import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:managevity/models/lesson.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/schedule_screen.dart';
import 'package:managevity/utils/dates.dart';
import 'package:managevity/widgets/resume_refresh.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  // A fixed moment: what counts as "earlier today" must not depend on when the tests run.
  final now = DateTime(2026, 10, 14, 13, 30);
  final early = DateTime(2026, 10, 14, 9);
  final late = DateTime(2026, 10, 14, 19);
  final noon = DateTime(2026, 10, 14, 12);

  void testWidgets(String description, Future<void> Function(WidgetTester) body) =>
      flutter_test.testWidgets(description, (t) => withClock(Clock.fixed(now), () => body(t)));

  testWidgets("shows today's lessons with their status", (tester) async {
    final api = FakeSportivityApi(
      lessons: [
        lessonFixture(id: 1, description: 'Yoga', start: late, status: 'Booked'),
        lessonFixture(id: 2, description: 'Spinning', start: late, spots: 0, activity: 'Spinning'),
        lessonFixture(id: 3, description: 'Not until tomorrow', start: addDays(noon, 1, hour: 12)),
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
            'UTCStartTime': late.toUtc().toIso8601String(),
            'UTCEndTime': late.add(const Duration(hours: 1)).toUtc().toIso8601String(),
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
        lessonFixture(id: 1, description: 'Yin yoga', start: late),
        lessonFixture(id: 2, description: 'Spinning 45', start: late, activity: 'Spinning'),
      ],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Spinning'));
    await tester.pumpAndSettle();
    expect(find.text('Spinning 45'), findsOneWidget);
    expect(find.text('Yin yoga'), findsNothing);
  });

  testWidgets('F5 fetches the day again', (tester) async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(description: 'Yin yoga', start: late)],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();
    expect(find.text('Yin yoga'), findsOneWidget);

    api.lessons = [lessonFixture(description: 'Spinning 45', start: late)];
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.text('Spinning 45'), findsOneWidget);
    expect(find.text('Yin yoga'), findsNothing);
  });

  group('coming back to the app', () {
    Future<void> leaveAndReturn(WidgetTester tester) async {
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
    }

    testWidgets('after a while: fetched again', (tester) async {
      final api = FakeSportivityApi(
        lessons: [lessonFixture(description: 'Yin yoga', start: late)],
      );
      await tester.pumpWidget(
        testApp(
          const ResumeRefresh(
            staleAfter: Duration.zero,
            child: _WithSession(child: ScheduleScreen()),
          ),
          api: api,
        ),
      );
      await tester.pumpAndSettle();

      api.lessons = [lessonFixture(description: 'Spinning 45', start: late)];
      await leaveAndReturn(tester);
      expect(find.text('Spinning 45'), findsOneWidget);
    });

    testWidgets('right away: the server is left alone', (tester) async {
      final api = FakeSportivityApi(
        lessons: [lessonFixture(description: 'Yin yoga', start: late)],
      );
      await tester.pumpWidget(
        testApp(
          const ResumeRefresh(child: _WithSession(child: ScheduleScreen())),
          api: api,
        ),
      );
      await tester.pumpAndSettle();
      final calls = api.scheduleCalls.length;

      api.lessons = [lessonFixture(description: 'Spinning 45', start: late)];
      await leaveAndReturn(tester);
      expect(find.text('Yin yoga'), findsOneWidget);
      expect(api.scheduleCalls, hasLength(calls));
    });
  });

  testWidgets('lessons that have started are folded away behind a button', (tester) async {
    final api = FakeSportivityApi(
      lessons: [
        lessonFixture(id: 1, description: 'Early bird', start: early),
        lessonFixture(id: 2, description: 'Night owl', start: late),
      ],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();
    expect(find.text('Night owl'), findsOneWidget);
    expect(find.text('Early bird'), findsNothing);

    await tester.tap(find.text('1 earlier lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Early bird'), findsOneWidget);
  });

  testWidgets('when everything today has started, it says so', (tester) async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(description: 'Early bird', start: early)],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();
    expect(find.text('No more lessons today.'), findsOneWidget);
    expect(find.text('1 earlier lesson'), findsOneWidget);
  });

  testWidgets('a date beyond the buttons can be picked, and the picker then shows it', (
    tester,
  ) async {
    final far = addDays(now, 20, hour: 19);
    final api = FakeSportivityApi(
      lessons: [lessonFixture(description: 'Far away', start: far)],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Other date'));
    await tester.pumpAndSettle();
    // Typed rather than tapped: which month the calendar opens on depends on today.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), DateFormat.yMd('en').format(far));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Far away'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, DateFormat.MMMEd('en').format(far)),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('the first lesson you are booked for is on top of today', (tester) async {
    final api = FakeSportivityApi(
      lessons: [
        lessonFixture(id: 1, description: 'Night owl', start: late),
        lessonFixture(
          id: 2,
          description: 'Later this week',
          start: addDays(now, 3, hour: 19),
          status: 'Booked',
        ),
        lessonFixture(
          id: 3,
          description: 'Tomorrow yoga',
          start: addDays(now, 1, hour: 19),
          status: 'Booked',
        ),
      ],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();
    expect(find.text('Your next lesson'), findsOneWidget);
    expect(find.textContaining('Tomorrow yoga'), findsOneWidget);
    expect(find.textContaining('Later this week'), findsNothing);
  });

  testWidgets('nothing booked: no "next lesson"', (tester) async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(description: 'Night owl', start: late)],
    );
    await tester.pumpWidget(testApp(const _WithSession(child: ScheduleScreen()), api: api));
    await tester.pumpAndSettle();
    expect(find.text('Your next lesson'), findsNothing);
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
