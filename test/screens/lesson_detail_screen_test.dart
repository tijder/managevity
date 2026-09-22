import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/models/lesson.dart';
import 'package:managevity/providers/lessons_provider.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/lesson_detail_screen.dart';
import 'package:managevity/services/sportivity_api.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

/// A lesson that is not covered by the membership: without BuyLesson the server refuses
/// and asks for a payment confirmation.
class _PaidLessonApi extends FakeSportivityApi {
  _PaidLessonApi({super.lessons});

  @override
  Future<BookingResult> joinLesson(int lessonId, int locationId, {bool buy = false}) async {
    if (buy) return super.joinLesson(lessonId, locationId, buy: true);
    joined.add((lessonId, false));
    return BookingResult(
      success: false,
      needsPayment: true,
      lesson: lessons.first.copyWith(),
      message: 'Payment required',
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final tomorrow = dayOf(DateTime.now()).add(const Duration(days: 1, hours: 19));

  Future<void> pump(WidgetTester tester, FakeSportivityApi api) async {
    await tester.pumpWidget(
      testApp(const _WithSession(child: LessonDetailScreen(lessonId: 5)), api: api),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('booking: one tap, without BuyLesson, and the button becomes Cancel booking', (
    tester,
  ) async {
    final api = FakeSportivityApi(lessons: [lessonFixture(id: 5, start: tomorrow)]);
    await pump(tester, api);

    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    expect(api.joined, [(5, false)]);
    expect(find.text('Cancel booking'), findsOneWidget);
    expect(find.text('Booked'), findsWidgets);
  });

  testWidgets('a paid lesson is only bought after a confirmation that shows the amount', (
    tester,
  ) async {
    final lesson = Lesson(
      id: 5,
      description: 'Workshop',
      startUtc: tomorrow.toUtc(),
      endUtc: tomorrow.add(const Duration(hours: 1)).toUtc(),
      bookingStatus: const BookingStatus(''),
      amount: '€ 7,50',
      participants: 4,
      maximumParticipants: 10,
    );
    final api = _PaidLessonApi(lessons: [lesson]);
    await pump(tester, api);
    // Both numbers, each saying what it counts.
    expect(find.text('4 of 10 going · 6 spots free'), findsOneWidget);

    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    expect(find.textContaining('€ 7,50'), findsOneWidget);
    expect(api.joined, [(5, false)]);

    // Back: nothing has been bought.
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(api.joined, [(5, false)]);
    expect(find.text('Book'), findsOneWidget);

    // Now do confirm.
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy and book'));
    await tester.pumpAndSettle();
    expect(api.joined.last, (5, true));
    expect(find.text('Cancel booking'), findsOneWidget);
  });

  testWidgets('cancelling asks for confirmation first', (tester) async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: tomorrow, status: 'Booked')],
    );
    await pump(tester, api);

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this booking?'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(api.cancelled, isEmpty);

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
    await tester.pumpAndSettle();
    expect(api.cancelled, [5]);
    expect(find.text('Book'), findsOneWidget);
  });

  testWidgets('full lesson without a waiting list: the button is disabled', (tester) async {
    final api = FakeSportivityApi(lessons: [lessonFixture(id: 5, start: tomorrow, spots: 0)]);
    await pump(tester, api);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Full'));
    expect(button.onPressed, isNull);
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
