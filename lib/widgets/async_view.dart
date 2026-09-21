import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:skeletonizer/skeletonizer.dart';

import '../l10n/l10n.dart';
import '../utils/errors.dart';

/// Loading / error with a retry button / content, for every screen that leans on a single
/// provider.
///
/// With a [placeholder], the real layout is drawn as a skeleton while loading, instead of a
/// spinner: the page is already there and does not jump when the content arrives. During a
/// refresh the old content simply stays put.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.placeholder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final T? placeholder;

  /// Loading that takes less than this shows no skeleton: a skeleton that makes way for the
  /// content a blink later makes a screen more restless than showing nothing for a moment.
  static const skeletonDelay = Duration(milliseconds: 250);

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  Timer? _timer;
  bool _showSkeleton = false;

  bool get _waiting => !widget.value.hasValue && !widget.value.hasError;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(AsyncView<T> old) {
    super.didUpdateWidget(old);
    _arm();
  }

  void _arm() {
    if (!_waiting) {
      _timer?.cancel();
      _timer = null;
      _showSkeleton = false;
    } else if (_timer == null && !_showSkeleton) {
      _timer = Timer(AsyncView.skeletonDelay, () {
        if (mounted) setState(() => _showSkeleton = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    // Align to the top: the default (centre) makes a short list drop a little during the
    // transition.
    layoutBuilder: (current, previous) =>
        Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
    child: KeyedSubtree(key: ValueKey(_stage), child: _content(context)),
  );

  String get _stage => widget.value.hasValue
      ? 'data'
      : widget.value.hasError
      ? 'error'
      : _showSkeleton
      ? 'skeleton'
      : 'wait';

  Widget _content(BuildContext context) {
    final value = widget.value;
    // Content first: an AsyncLoading or AsyncError that *has* a previous value is a
    // refresh, and then what was there beats an empty screen.
    if (value.hasValue) return widget.builder(value.requireValue);
    if (value.hasError) {
      return ErrorView(message: describeError(context.l10n, value.error!), onRetry: widget.onRetry);
    }
    final shape = widget.placeholder;
    if (!_showSkeleton) {
      // Show nothing yet, but do take up the space already: that way the rest of the page
      // does not jump when the content (or the skeleton) comes in.
      return shape == null
          ? const SizedBox.shrink()
          : Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: widget.builder(shape),
            );
    }
    if (shape == null) return const Center(child: CircularProgressIndicator());
    return Skeletonizer(
      // A skeleton is not a button: tapping fake data must not lead anywhere.
      ignorePointers: true,
      child: widget.builder(shape),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(context.l10n.errorGeneric, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    ),
  );
}

class EmptyView extends StatelessWidget {
  const EmptyView(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // Scrollable, so pull-to-refresh works on an empty list too.
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: constraints.maxHeight,
        child: Center(child: Text(message)),
      ),
    ),
  );
}
