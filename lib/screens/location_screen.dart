import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/session_provider.dart';
import '../router/app_router.dart';
import '../widgets/async_view.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';

@RoutePage()
class LocationScreen extends ConsumerWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final current = ref.watch(sessionProvider).value?.location;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.locationTitle)),
      body: AsyncView(
        value: ref.watch(locationsProvider),
        placeholder: placeholderLocations,
        onRetry: () => ref.invalidate(locationsProvider),
        builder: (locations) => locations.isEmpty
            ? EmptyView(l10n.locationNone)
            : ResponsiveListView(
                maxWidth: 640,
                children: [
                  for (final location in locations)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(location.name),
                        trailing: location.id == current?.id ? const Icon(Icons.check) : null,
                        onTap: () async {
                          await ref.read(sessionProvider.notifier).chooseLocation(location);
                          if (context.mounted) {
                            await continueAfterSession(context.router, ref);
                          }
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
