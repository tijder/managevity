import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/invoice.dart';
import 'package:managevity/widgets/invoice_chart.dart';

Invoice inv(int id, String? date, double? amount) =>
    Invoice(id: id, number: '$id', date: date, amountValue: amount);

void main() {
  test('date: dd-MM-yyyy, also with a time after it; nonsense becomes null', () {
    expect(inv(1, '27-08-2026', 1).dateValue, DateTime(2026, 8, 27));
    expect(inv(1, '27-08-2026 15:55', 1).dateValue, DateTime(2026, 8, 27));
    expect(inv(1, '2026-08-27', 1).dateValue, isNull);
    expect(inv(1, '27-13-2026', 1).dateValue, isNull);
    expect(inv(1, null, 1).dateValue, isNull);
  });

  test('adds up per month and splits outstanding from paid', () {
    final totals = monthlyTotals(
      [inv(1, '27-08-2026', 70), inv(2, '03-08-2026', 5), inv(3, '30-07-2026', 70)],
      {1},
    );
    expect(totals.map((t) => t.month), [DateTime(2026, 7), DateTime(2026, 8)]);
    expect((totals[0].paid, totals[0].open), (70, 0));
    expect((totals[1].paid, totals[1].open), (5, 70));
    expect(totals[1].total, 75);
  });

  test('a month without an invoice stays in the series as a gap', () {
    final totals = monthlyTotals([inv(1, '15-03-2026', 10), inv(2, '15-01-2026', 10)], {});
    expect(totals.map((t) => t.total), [10, 0, 10]);
  });

  test('at most twelve months, ending at the newest invoice; across the turn of the year', () {
    final totals = monthlyTotals([
      for (var m = 0; m < 20; m++)
        inv(m, '01-${(m % 12 + 1).toString().padLeft(2, '0')}-${2025 + m ~/ 12}', 10),
    ], {});
    expect(totals, hasLength(12));
    expect(totals.first.month, DateTime(2025, 9));
    expect(totals.last.month, DateTime(2026, 8));
  });

  test('invoices without a readable date or amount do not count', () {
    expect(monthlyTotals([inv(1, 'yesterday', 10), inv(2, '01-01-2026', null)], {}), isEmpty);
  });
}
