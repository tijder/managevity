import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:managevity/models/invoice.dart';
import 'package:managevity/providers/session_provider.dart';
import 'package:managevity/screens/invoices_screen.dart';

import '../fixtures/fixtures.dart';
import 'helpers.dart';

class _Api extends FakeSportivityApi {
  _Api(this.all);
  final List<Invoice> all;
  static const openId = 3;

  // Like the server: `all: false` returns only what is still outstanding.
  @override
  Future<List<Invoice>> invoices(int locationId, {bool all = true}) async => [
    for (final i in this.all)
      if (all || i.id == openId) i,
  ];
}

Invoice invoice(int id, String date, {String status = 'Paid'}) => Invoice(
  id: id,
  number: '2026-00$id',
  date: date,
  status: status,
  amount: '€ 70,00',
  amountValue: 70,
);

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  _payTests();

  Future<void> pump(WidgetTester tester, List<Invoice> invoices) async {
    await tester.pumpWidget(
      testApp(const _WithSession(child: InvoicesScreen()), api: _Api(invoices)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('all: grouped by year, the outstanding invoice is recognisable', (tester) async {
    await pump(tester, [
      invoice(3, '27-08-2026', status: 'Open'),
      invoice(2, '30-07-2026'),
      invoice(1, '30-12-2025'),
    ]);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);
    expect(find.text('1 invoice outstanding'), findsOneWidget);
    // Two paid invoices plus the legend of the chart.
    expect(find.text('Paid'), findsNWidgets(3));
    // Filter button, status on the outstanding invoice, legend.
    expect(find.text('Outstanding'), findsNWidgets(3));
    expect(find.text('Per month'), findsOneWidget);
  });

  testWidgets('filter "Outstanding" shows only what the server considers open', (tester) async {
    await pump(tester, [invoice(3, '27-08-2026', status: 'Open'), invoice(2, '30-07-2026')]);
    await tester.tap(find.widgetWithText(SegmentedButton<bool>, 'Outstanding'));
    await tester.pumpAndSettle();
    expect(find.text('27-08-2026'), findsOneWidget);
    expect(find.text('30-07-2026'), findsNothing);
  });

  testWidgets('nothing outstanding: it says so, under the filter too', (tester) async {
    await pump(tester, [invoice(2, '30-07-2026')]);
    expect(find.text('Everything is paid.'), findsOneWidget);
    await tester.tap(find.text('Outstanding'));
    await tester.pumpAndSettle();
    expect(find.text('30-07-2026'), findsNothing);
    expect(find.text('Everything is paid.'), findsNWidgets(2));
  });
}

void _payTests() {
  testWidgets('paying: the amount first, the payment page only after yes', (tester) async {
    final api = _Api([invoice(3, '27-08-2026', status: 'Open')]);
    final opened = <Uri>[];
    await tester.pumpWidget(
      testApp(
        const _WithSession(child: InvoicesScreen()),
        api: api,
        opened: opened,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(find.textContaining('outstanding amount of €70.00'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(api.paymentRequests, isEmpty);

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('To the payment page'));
    await tester.pumpAndSettle();
    expect(api.paymentRequests, [('invoices', null)]);
    expect(opened, [FakeSportivityApi.paymentPage]);
  });

  testWidgets('nothing outstanding: no pay button', (tester) async {
    await tester.pumpWidget(
      testApp(const _WithSession(child: InvoicesScreen()), api: _Api([invoice(1, '30-07-2026')])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pay'), findsNothing);
  });
}

class _WithSession extends ConsumerWidget {
  const _WithSession({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(sessionProvider).value?.ready == true ? child : const SizedBox.shrink();
}
