import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/session_provider.dart';
import '../router/app_router.dart';
import '../services/demo_server.dart';
import '../utils/errors.dart';
import '../widgets/responsive.dart';

/// What this app is and what sets it apart. Public on purpose (no session guard): it is
/// linked from the login screen, and on the web it is the page a search engine or a curious
/// visitor can read without an account.
@RoutePage()
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loggedIn = ref.watch(sessionProvider).value?.loggedIn ?? false;

    Future<void> openDemo() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(sessionProvider.notifier)
            .login(DemoServer.user, DemoServer.password, remember: false);
        if (context.mounted) await continueAfterSession(context.router, ref);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ResponsiveListView(
        maxWidth: 1000,
        padding: 16,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/icon/icon.png', width: 72, height: 72),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.appTitle, style: theme.textTheme.headlineMedium),
                    Text(
                      l10n.appSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.aboutIntro, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          // The three things that make it different first; two columns when there is room.
          CardGrid(
            minTileWidth: 420,
            maxColumns: 2,
            children: [
              _Feature(
                icon: Icons.devices_outlined,
                title: l10n.aboutFeatureDesktopTitle,
                body: l10n.aboutFeatureDesktopBody,
              ),
              _Feature(
                icon: Icons.shield_outlined,
                title: l10n.aboutFeaturePrivacyTitle,
                body: kIsWeb
                    ? '${l10n.aboutFeaturePrivacyBody} ${l10n.aboutWebNote}'
                    : l10n.aboutFeaturePrivacyBody,
              ),
              _Feature(
                icon: Icons.event_available_outlined,
                title: l10n.aboutFeatureCalendarTitle,
                body: l10n.aboutFeatureCalendarBody,
              ),
              _Feature(
                icon: Icons.auto_awesome_outlined,
                title: l10n.aboutFeatureMoreTitle,
                body: l10n.aboutFeatureMoreBody,
              ),
            ],
          ),
          if (!loggedIn) ...[
            const SizedBox(height: 8),
            Card(
              color: scheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aboutDemoTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.aboutDemoBody, style: TextStyle(color: scheme.onSecondaryContainer)),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: openDemo,
                      icon: const Icon(Icons.science_outlined),
                      label: Text(l10n.aboutDemoButton),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(l10n.disclaimer, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(l10n.aboutSource, style: theme.textTheme.bodySmall),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationIcon: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/icon/icon.png', width: 48, height: 48),
                ),
              ),
              child: Text(l10n.aboutLicences),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
