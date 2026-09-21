import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../providers/content_providers.dart';
import '../utils/html_text.dart';
import '../widgets/async_view.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';
import '../widgets/refreshable.dart';

/// News and notifications have the same shape; [notifications] picks the source.
@RoutePage()
class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key, @QueryParam('notifications') this.notifications = false});

  final bool notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final provider = notifications ? notificationsProvider : newsProvider;
    Future<void> refresh() => ref.refresh(provider.future);
    return Scaffold(
      appBar: AppBar(
        title: Text(notifications ? l10n.moreNotifications : l10n.moreNews),
        actions: [RefreshAction(onRefresh: refresh)],
      ),
      body: Refreshable(
        onRefresh: refresh,
        child: AsyncView(
          value: ref.watch(provider),
          placeholder: placeholderNews,
          onRetry: () => ref.invalidate(provider),
          builder: (items) => items.isEmpty
              ? EmptyView(l10n.listEmpty)
              : ResponsiveListView(
                  children: [
                    for (final item in items)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.date != null)
                                Text(
                                  DateFormat.yMMMd(locale).format(item.date!),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              SelectableText(htmlToText(item.html ?? item.description ?? '')),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
