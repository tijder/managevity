import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/models/lesson.dart';
import 'package:managevity/providers/lessons_provider.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/lesson_detail_screen.dart';
import 'package:managevity/services/sportivity_api.dart';
import 'package:managevity/utils/dates.dart';
import 'package:managevity/utils/errors.dart';

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

/// Remembers what the server was told about the heart, and answers when the test says so.
class _LikingApi extends FakeSportivityApi {
  _LikingApi({super.lessons});

  final likes = <bool>[];
  var gate = Completer<void>();

  @override
  Future<bool> likeLesson(int lessonId, int locationId, {required bool like}) async {
    likes.add(like);
    await gate.future;
    lessons = [for (final l in lessons) l.id == lessonId ? l.copyWith(liked: like) : l];
    return true;
  }
}

/// No connection for the lesson itself.
class _UnreachableLessonApi extends FakeSportivityApi {
  @override
  Future<Lesson> lesson(int lessonId) async => throw const SportivityException(AppError.network);
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final tomorrow = addDays(DateTime.now(), 1, hour: 19);

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

  testWidgets('the cancel question says which lesson, and when', (tester) async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, description: 'Yin yoga', start: tomorrow, status: 'Booked')],
    );
    await pump(tester, api);
    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.textContaining('Yin yoga')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.textContaining('19:00')), findsOneWidget);
  });

  testWidgets('a lesson that is under way can no longer be booked', (tester) async {
    final api = FakeSportivityApi(
      lessons: [lessonFixture(id: 5, start: DateTime.now().subtract(const Duration(minutes: 10)))],
    );
    await pump(tester, api);
    expect(find.text('This lesson has already started.'), findsOneWidget);
    expect(find.text('Book'), findsNothing);
  });

  testWidgets('the heart turns at once and a second tap waits for the first', (tester) async {
    final api = _LikingApi(lessons: [lessonFixture(id: 5, start: tomorrow)]);
    await pump(tester, api);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pump();
    expect(api.likes, [true]);

    api.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    api.gate = Completer<void>()..complete();
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();
    expect(api.likes, [true, false]);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('without a connection the lesson from the list is shown', (tester) async {
    final lesson = lessonFixture(id: 5, description: 'Yin yoga', start: tomorrow);
    await tester.pumpWidget(
      testApp(
        _WithSession(
          child: _Remembered(lesson: lesson, child: const LessonDetailScreen(lessonId: 5)),
        ),
        api: _UnreachableLessonApi(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yin yoga'), findsWidgets);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('without a connection and never seen: an error with a retry', (tester) async {
    await pump(tester, _UnreachableLessonApi());
    expect(find.text('Retry'), findsOneWidget);
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

/// As if the lesson was tapped in a list: that is where the detail screen gets its preview.
class _Remembered extends ConsumerWidget {
  const _Remembered({required this.lesson, required this.child});
  final Lesson lesson;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(lessonPreviewsProvider).remember(lesson);
    return child;
  }
}
