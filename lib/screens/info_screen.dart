import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../providers/content_providers.dart';
import '../utils/html_text.dart';
import '../widgets/async_view.dart';
import '../widgets/responsive.dart';
import '../widgets/placeholders.dart';

/// The gym's contact details or house rules.
@RoutePage()
class InfoScreen extends ConsumerWidget {
  const InfoScreen({super.key, @QueryParam('rules') this.rules = false});

  final bool rules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = rules ? requirementsHtmlProvider : contactHtmlProvider;
    return Scaffold(
      appBar: AppBar(title: Text(rules ? l10n.moreRules : l10n.moreContact)),
      body: AsyncView(
        value: ref.watch(provider),
        placeholder: placeholderText,
        onRetry: () => ref.invalidate(provider),
        builder: (html) => html == null
            ? EmptyView(l10n.listEmpty)
            : ResponsiveListView(
                padding: 16,
                children: [
                  SelectableText(htmlToText(html), style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
      ),
    );
  }
}
