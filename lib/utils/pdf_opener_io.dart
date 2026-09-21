import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Android: the share sheet (open in a PDF reader, save, forward).
/// Desktop: share_plus cannot share files there, so the file goes to Downloads and is
/// opened with whatever program the system has for PDFs.
/// Returns where the file ended up, or null if that cannot be told.
Future<String?> openPdf(Uint8List bytes, String fileName) async {
  if (Platform.isAndroid || Platform.isIOS) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName)],
        fileNameOverrides: [fileName],
      ),
    );
    return null;
  }
  final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  // If opening fails (no PDF reader), the file is at least there.
  await launchUrl(Uri.file(file.path));
  return file.path;
}
