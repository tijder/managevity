import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Asks before doing something that changes the account or costs money.
///
/// [lines] say exactly what is about to happen: what, from when, for how much. Nothing in
/// this app changes a membership or starts a payment without this question first. With
/// [irreversible] a second question follows, in the error colour: cancelling a membership
/// cannot be undone from the app.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required List<String> lines,
  required String confirmLabel,
  bool irreversible = false,
}) async {
  final l10n = context.l10n;

  Future<bool> ask(String title, List<String> lines, {bool danger = false}) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(line)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.back)),
            FilledButton(
              style: danger
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return answer == true;
  }

  if (!await ask(title, lines)) return false;
  if (!irreversible) return true;
  if (!context.mounted) return false;
  return ask(l10n.confirmSureTitle, [l10n.confirmIrreversible], danger: true);
}
