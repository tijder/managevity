import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../utils/errors.dart';

/// Pulling down only works with a finger. With a mouse and keyboard there is the button in
/// the app bar ([RefreshAction]) and F5 / Ctrl+R.
/// Runs [onRefresh] and reports a failure in a snackbar. Without this a failed refresh is
/// invisible: the old content stays on screen (by design) and the error vanishes into the
/// RefreshIndicator.
Future<void> _guardedRefresh(BuildContext context, Future<void> Function() onRefresh) async {
  // Tolerant on purpose: this wraps every page, including ones shown without the app's
  // localizations (tests, error pages). English is the fallback.
  final l10n = AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await onRefresh();
  } catch (e) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.errorRefreshFailed(describeError(l10n, e)))));
  }
}

bool get _pointerPlatform =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.linux || TargetPlatform.windows || TargetPlatform.macOS => true,
      _ => false,
    };

/// Pull-to-refresh plus the keyboard shortcuts, wrapped around a scrolling page.
///
/// The keys are attached to the keyboard itself and not to the focus: after a click on the
/// app bar or a day button the focus lies outside this page, and F5 then did nothing. Only
/// the page you are looking at responds — not the tabs that live on invisibly, and not a
/// page that has another one on top of it.
class Refreshable extends StatefulWidget {
  const Refreshable({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<Refreshable> createState() => _RefreshableState();
}

class _RefreshableState extends State<Refreshable> {
  final _indicator = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final isRefresh =
        event.logicalKey == LogicalKeyboardKey.f5 ||
        (event.logicalKey == LogicalKeyboardKey.keyR && HardwareKeyboard.instance.isControlPressed);
    if (!isRefresh) return false;
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (!current || !Visibility.of(context)) return false;
    // show() drops the familiar spinning indicator down from the top and calls onRefresh:
    // the same feedback as pulling down.
    _indicator.currentState?.show();
    return true;
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    key: _indicator,
    onRefresh: () => _guardedRefresh(context, widget.onRefresh),
    child: widget.child,
  );
}

/// The refresh button for `AppBar.actions`; spins for as long as the refresh runs. Not shown
/// on a phone: pulling down is the habit there and the app bar is full enough as it is.
class RefreshAction extends StatefulWidget {
  const RefreshAction({super.key, required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  State<RefreshAction> createState() => _RefreshActionState();
}

class _RefreshActionState extends State<RefreshAction> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await _guardedRefresh(context, widget.onRefresh);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_pointerPlatform) return const SizedBox.shrink();
    return IconButton(
      tooltip: '${context.l10n.refresh} (F5)',
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh),
    );
  }
}
