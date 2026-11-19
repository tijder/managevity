import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/content_providers.dart';
import '../providers/lessons_provider.dart';

/// Fetches what is on screen again when the app comes back after a while.
///
/// Without this an app left open in the morning shows the morning's free spots in the
/// evening, with nothing saying so. Not on every return: switching to the calendar and back
/// is not a reason to call somebody else's server again. A failure is silent here — the old
/// content stays, and if the server cannot be reached the offline strip says so.
class ResumeRefresh extends ConsumerStatefulWidget {
  const ResumeRefresh({super.key, required this.child, this.staleAfter = defaultStaleAfter});

  static const defaultStaleAfter = Duration(minutes: 10);

  final Widget child;
  final Duration staleAfter;

  @override
  ConsumerState<ResumeRefresh> createState() => _ResumeRefreshState();
}

class _ResumeRefreshState extends ConsumerState<ResumeRefresh> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // "hidden" is the one state every platform passes through on the way out, including
      // a browser tab that moves to the background.
      onHide: () => _leftAt ??= DateTime.now(),
      onResume: _resumed,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _resumed() {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null || DateTime.now().difference(leftAt) < widget.staleAfter) return;

    // Whole families: whichever day is on screen fetches again, the rest is dropped.
    ref.invalidate(scheduleWeekProvider);
    ref.invalidate(scheduleProvider);
    ref.invalidate(heatmapDayProvider);
    ref.invalidate(heatmapWeekProvider);
    // Not invalidated but refreshed: the calendar should follow, and a failure must leave
    // the list that is there alone.
    if (ref.exists(bookedLessonsProvider)) {
      ref
          .read(bookedLessonsProvider.notifier)
          .refreshAndSync()
          .then(
            (_) {},
            onError: (Object e) {
              debugPrint('[resume] refreshing booked lessons failed: $e');
            },
          );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
