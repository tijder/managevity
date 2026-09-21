import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/l10n.dart';
import '../providers/content_providers.dart';
import '../providers/services.dart';
import '../providers/session_provider.dart';
import '../utils/errors.dart';
import '../utils/photo.dart';
import 'customer_avatar.dart';

/// Gets an image from the user; null if they back out. Separate from the widget, so tests
/// can substitute a fixed image.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => (source) async {
    // maxWidth/imageQuality work on phone and web; on desktop the plugin ignores them, and
    // there preparePhoto takes care of the large file.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: kPhotoMaxSide * 2,
      maxHeight: kPhotoMaxSide * 2,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  },
);

/// The avatar with a small button to replace the ID photo.
class EditableCustomerAvatar extends ConsumerStatefulWidget {
  const EditableCustomerAvatar({super.key, required this.name, this.radius = 40});

  final String? name;
  final double radius;

  @override
  ConsumerState<EditableCustomerAvatar> createState() => _EditableCustomerAvatarState();
}

class _EditableCustomerAvatarState extends ConsumerState<EditableCustomerAvatar> {
  bool _busy = false;

  bool get _hasCamera => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _change() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    // There is only a camera on the phone; elsewhere it goes straight to "pick a file".
    final source = !_hasCamera
        ? ImageSource.gallery
        : await showModalBottomSheet<ImageSource>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(l10n.photoCamera),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text(l10n.photoGallery),
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          );
    if (source == null) return;

    try {
      final picked = await ref.read(photoPickerProvider)(source);
      if (picked == null || !mounted) return;
      final Uint8List photo;
      try {
        photo = await preparePhoto(picked);
      } on FormatException {
        messenger.showSnackBar(SnackBar(content: Text(l10n.photoInvalid)));
        return;
      }
      if (!mounted) return;

      // This overwrites something at the gym that cannot be brought back: first show what
      // is going to be sent, and say what it is for.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.photoConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 72, backgroundImage: MemoryImage(photo)),
              const SizedBox(height: 16),
              Text(l10n.photoConfirmBody),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.back)),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.photoUpload),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      setState(() => _busy = true);
      final message = await ref
          .read(apiProvider)
          .uploadCustomerPhoto(ref.read(locationIdProvider), photo);
      ref.invalidate(customerPhotoProvider);
      messenger.showSnackBar(SnackBar(content: Text(message ?? l10n.photoUploaded)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(describeError(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomerAvatar(name: widget.name, radius: widget.radius),
        if (_busy)
          Positioned.fill(
            child: CircularProgressIndicator(color: scheme.onPrimaryContainer, strokeWidth: 3),
          ),
        Positioned(
          right: -6,
          bottom: -6,
          child: IconButton.filled(
            tooltip: context.l10n.photoChange,
            onPressed: _busy ? null : _change,
            icon: Icon(_hasCamera ? Icons.photo_camera : Icons.upload, size: 18),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(34),
              padding: EdgeInsets.zero,
              backgroundColor: scheme.surface,
              foregroundColor: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
