import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/content_providers.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../router/app_router.dart';
import '../widgets/customer_avatar.dart';
import '../widgets/responsive.dart';

@RoutePage()
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final location = ref.watch(sessionProvider).value?.location;
    final customer = ref.watch(userContentProvider).value?.customer;
    final router = context.router.root;
    final buttons = ref.watch(gymButtonsProvider).value ?? const [];
    final logo = ref.watch(gymLogoProvider).value;

    Widget item(IconData icon, String title, PageRouteInfo route, {String? subtitle}) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => router.push(route),
    );

    // A group of tiles in a single card, with thin lines in between.
    Widget group(List<Widget> tiles) => Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, tile) in tiles.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            tile,
          ],
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabMore)),
      body: ResponsiveListView(
        children: [
          Card(
            color: scheme.primaryContainer,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => router.push(const ProfileRoute()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CustomerAvatar(name: customer?.fullName),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer?.fullName ?? l10n.moreProfile,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          if (location != null)
                            Text(
                              location.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
                  ],
                ),
              ),
            ),
          ),
          SectionTitle(l10n.moreSectionLessons),
          group([
            item(Icons.sync, l10n.moreSync, const SyncSettingsRoute()),
            item(Icons.favorite_border, l10n.moreFavourites, const FavouritesRoute()),
          ]),
          SectionTitle(l10n.moreSectionGym),
          group([
            if (logo != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 56,
                  child: logo.bytes != null
                      ? Image.memory(logo.bytes!, errorBuilder: (_, _, _) => const SizedBox())
                      : Image.network('${logo.uri}', errorBuilder: (_, _, _) => const SizedBox()),
                ),
              ),
            item(Icons.campaign_outlined, l10n.moreNews, NewsRoute(notifications: false)),
            item(Icons.notifications_none, l10n.moreNotifications, NewsRoute(notifications: true)),
            item(Icons.contact_support_outlined, l10n.moreContact, InfoRoute(rules: false)),
            item(Icons.gavel_outlined, l10n.moreRules, InfoRoute(rules: true)),
            // Links the gym put in its own app.
            for (final button in buttons)
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(button.label),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => ref.read(openExternalProvider)(button.uri),
              ),
          ]),
          SectionTitle(l10n.moreSectionAccount),
          group([
            item(Icons.card_membership, l10n.moreMemberships, const MembershipsRoute()),
            item(Icons.storefront_outlined, l10n.moreOffers, OffersRoute()),
            item(Icons.receipt_long_outlined, l10n.moreInvoices, const InvoicesRoute()),
            item(Icons.group_add_outlined, l10n.moreGuests, const GuestsRoute()),
            item(
              Icons.place_outlined,
              l10n.moreLocation,
              const LocationRoute(),
              subtitle: location?.name,
            ),
          ]),
          SectionTitle(l10n.moreSectionApp),
          group([
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.moreAbout),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => router.push(const AboutRoute()),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(l10n.moreLogout, style: TextStyle(color: scheme.error)),
              onTap: () async {
                await ref.read(sessionProvider.notifier).logout();
                router.replaceAll([const LoginRoute()]);
              },
            ),
          ]),
        ],
      ),
    );
  }
}
