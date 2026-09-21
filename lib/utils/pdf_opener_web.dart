import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// In the browser: share where possible, otherwise share_plus turns it into a download.
/// Returns where the file ended up, or null if that cannot be told.
Future<String?> openPdf(Uint8List bytes, String fileName) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
      fileNameOverrides: [fileName],
    ),
  );
  return null;
}
