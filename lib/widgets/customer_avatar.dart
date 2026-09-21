import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/content_providers.dart';

/// The customer's ID photo, with the initials if there is no photo (or while it loads).
class CustomerAvatar extends ConsumerWidget {
  const CustomerAvatar({super.key, required this.name, this.radius = 28});

  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final photo = ref.watch(customerPhotoProvider).value;
    final initials = (name ?? '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      // An unreadable image falls back to the initials instead of an error box.
      foregroundImage: photo == null ? null : MemoryImage(photo),
      onForegroundImageError: photo == null ? null : (_, _) {},
      child: initials.isEmpty
          ? Icon(Icons.person, size: radius)
          : Text(
              initials,
              style: TextStyle(color: scheme.onPrimary, fontSize: radius * 0.7),
            ),
    );
  }
}
