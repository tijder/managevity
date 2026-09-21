import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/lessons_provider.dart';
import '../providers/session_provider.dart';
import '../router/app_router.dart';

@RoutePage()
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(sessionProvider).value?.demo ?? false;
    final offline = ref.watch(offlineProvider);
    final l10n = context.l10n;
    final destinations = [
      (Icons.calendar_view_day_outlined, Icons.calendar_view_day, l10n.tabSchedule),
      (Icons.event_available_outlined, Icons.event_available, l10n.tabMyLessons),
      (Icons.bar_chart_outlined, Icons.bar_chart, l10n.tabBusy),
      (Icons.more_horiz, Icons.more_horiz, l10n.tabMore),
    ];
    return AutoTabsRouter(
      routes: const [ScheduleRoute(), MyLessonsRoute(), BusyRoute(), MoreRoute()],
      builder: (context, child) {
        final tabs = AutoTabsRouter.of(context);
        final wide = MediaQuery.sizeOf(context).width >= 720;
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: tabs.activeIndex,
                  onDestinationSelected: tabs.setActiveIndex,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final (icon, selected, label) in destinations)
                      NavigationRailDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _StatusFrame(demo: demo, offline: offline, child: child),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: _StatusFrame(demo: demo, offline: offline, child: child),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tabs.activeIndex,
            onDestinationSelected: tabs.setActiveIndex,
            destinations: [
              for (final (icon, selected, label) in destinations)
                NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
            ],
          ),
        );
      },
    );
  }
}

/// Strips across the top for states the user must not miss: the demo (so nobody mistakes
/// made-up lessons for a real booking) and offline (so nobody trusts a list that may be
/// hours old — a lesson shown as free may long be full).
class _StatusFrame extends StatelessWidget {
  const _StatusFrame({required this.demo, required this.offline, required this.child});

  final bool demo;
  final bool offline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!demo && !offline) return child;
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    Widget strip(IconData icon, String text, Color background, Color foreground) => Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        // One SafeArea for both strips: they cover the status bar together.
        Material(
          color: demo ? scheme.tertiaryContainer : scheme.errorContainer,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (demo)
                  strip(
                    Icons.science_outlined,
                    l10n.demoBanner,
                    scheme.tertiaryContainer,
                    scheme.onTertiaryContainer,
                  ),
                if (offline)
                  strip(
                    Icons.cloud_off_outlined,
                    l10n.offlineBanner,
                    scheme.errorContainer,
                    scheme.onErrorContainer,
                  ),
              ],
            ),
          ),
        ),
        // The strips already cover the status bar; the page below must not pad for it again.
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}
