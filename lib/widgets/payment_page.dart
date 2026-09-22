import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/services.dart';
import '../utils/errors.dart';

/// Asks the gym for a payment page and opens it in the browser. Paying itself happens
/// there; call this only after [confirmAction] showed the amount. True if the page opened.
Future<bool> openPaymentPage(
  BuildContext context,
  WidgetRef ref,
  Future<Uri> Function() page,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final opened = await ref.read(openExternalProvider)(await page());
    messenger.showSnackBar(
      SnackBar(content: Text(opened ? l10n.paymentOpened : l10n.paymentCouldNotOpen)),
    );
    return opened;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    return false;
  }
}

/// Calls [onReturn] once the app comes back to the foreground after a payment page was
/// opened, so that the balance or the invoices show the payment without a manual refresh.
mixin RefreshAfterPayment<T extends StatefulWidget> on State<T> {
  AppLifecycleListener? _lifecycle;
  bool _paying = false;

  void onReturn();

  /// Call when a payment page has been opened.
  void paymentStarted() {
    _lifecycle ??= AppLifecycleListener(onResume: _resumed);
    _paying = true;
  }

  void _resumed() {
    if (!_paying) return;
    _paying = false;
    onReturn();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }
}
