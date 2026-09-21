import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/l10n/l10n.dart';
import 'package:managevity/widgets/lesson_card.dart';

import 'fixtures/fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<void> pump(WidgetTester tester, DateTime start) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: LessonCard(
          lesson: lessonFixture(start: start),
          showDate: true,
          onTap: () {},
        ),
      ),
    ),
  );

  final thisYear = DateTime.now().year;

  testWidgets('this year: no year shown', (tester) async {
    await pump(tester, DateTime(thisYear, 3, 5, 19));
    expect(find.textContaining('March 5'), findsOneWidget);
    expect(find.textContaining('$thisYear'), findsNothing);
  });

  testWidgets('another year: with the year', (tester) async {
    await pump(tester, DateTime(thisYear - 1, 3, 5, 19));
    expect(find.textContaining('March 5, ${thisYear - 1}'), findsOneWidget);
  });
}
