import 'dart:typed_data';
import 'dart:ui' as ui;

/// Longest side at which an ID photo is sent. Large enough for a recognisable face at the
/// front desk, and small enough to fit as base64 in a single JSON request.
const kPhotoMaxSide = 720;

/// Files up to this size go out unchanged (usually a JPEG from the phone that image_picker
/// has already downscaled).
const kPhotoMaxBytes = 400 * 1024;

/// Prepares [bytes] for upload. A small file stays as it is; a large one is downscaled.
/// `dart:ui` can only write PNG, so a downscaled photo becomes a PNG.
/// Throws a [FormatException] if it is not an image.
Future<Uint8List> preparePhoto(Uint8List bytes) async {
  final ui.Codec probe;
  try {
    probe = await ui.instantiateImageCodec(bytes);
  } on Exception {
    throw const FormatException('not an image');
  }
  final original = (await probe.getNextFrame()).image;
  final longest = original.width > original.height ? original.width : original.height;
  if (bytes.length <= kPhotoMaxBytes && longest <= kPhotoMaxSide * 2) {
    original.dispose();
    return bytes;
  }

  final landscape = original.width >= original.height;
  original.dispose();
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: landscape ? kPhotoMaxSide : null,
    targetHeight: landscape ? null : kPhotoMaxSide,
  );
  final small = (await codec.getNextFrame()).image;
  final png = await small.toByteData(format: ui.ImageByteFormat.png);
  small.dispose();
  if (png == null) throw const FormatException('downscaling failed');
  return png.buffer.asUint8List();
}
