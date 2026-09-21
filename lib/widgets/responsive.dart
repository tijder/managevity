import 'package:flutter/material.dart';

/// From this width on a screen counts as "wide" (navigation rail, grids, two columns).
const kWideBreakpoint = 720.0;

/// A scrolling page whose content does not stretch beyond [maxWidth] on wide screens. The
/// list itself stays full width — so scrolling and pull-to-refresh also work in the
/// margins, and the scrollbar sits at the edge of the window.
class ResponsiveListView extends StatelessWidget {
  const ResponsiveListView({
    super.key,
    required this.children,
    this.maxWidth = 760,
    this.padding = 12,
  });

  final List<Widget> children;
  final double maxWidth;
  final double padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = ((constraints.maxWidth - maxWidth) / 2).clamp(padding, double.infinity);
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(side, padding, side, padding + 12),
        children: children,
      );
    },
  );
}

/// Cards side by side as soon as there is room: as many columns of [minTileWidth] as fit,
/// at most [maxColumns]. Cards in the same row get the same height.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.minTileWidth = 360, this.maxColumns = 3});

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / minTileWidth).floor().clamp(1, maxColumns);
      if (columns == 1) return Column(children: children);
      return Column(
        children: [
          for (var i = 0; i < children.length; i += columns)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + columns; j++)
                    Expanded(child: j < children.length ? children[j] : const SizedBox()),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Like a [ResponsiveListView] with a [CardGrid] inside, but lazy: only the rows in view
/// are built. For long lists in which every card fetches something itself.
class LazyCardGrid extends StatelessWidget {
  const LazyCardGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxWidth = 1200,
    this.minTileWidth = 360,
    this.maxColumns = 3,
    this.padding = 12,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double maxWidth;
  final double minTileWidth;
  final int maxColumns;
  final double padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = ((constraints.maxWidth - maxWidth) / 2).clamp(padding, double.infinity);
      final width = constraints.maxWidth - 2 * side;
      final columns = (width / minTileWidth).floor().clamp(1, maxColumns);
      final rows = (itemCount / columns).ceil();
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(side, padding, side, padding + 12),
        itemCount: rows,
        itemBuilder: (context, row) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = row * columns; i < (row + 1) * columns; i++)
                Expanded(child: i < itemCount ? itemBuilder(context, i) : const SizedBox()),
            ],
          ),
        ),
      );
    },
  );
}

/// A heading above a group, as in settings screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// Label with a value, for detail cards.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
