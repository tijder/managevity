import 'dart:convert';
import 'dart:typed_data';

import '../utils/json.dart';

/// A link the gym has put in its app itself (`Button`). The shape of an item has not been
/// seen in real data ("No buttons found"), so this reads the likely field names and shows a
/// button only when it finds both a label and a web address.
class GymButton {
  const GymButton({required this.label, required this.uri});

  final String label;
  final Uri uri;

  static GymButton? tryFromJson(Json json) {
    final label = _first(json, ['Text', 'ButtonText', 'Title', 'Name', 'Description']);
    final uri = _webAddress(_first(json, ['Url', 'URL', 'Link', 'ButtonUrl', 'Href']));
    if (label == null || uri == null) return null;
    return GymButton(label: label, uri: uri);
  }
}

/// The gym's logo (`Location/LogoLocation`). Only an image that comes along in the answer
/// (Base64): an address would make the app fetch from wherever it points, and the app
/// promises to talk only to the gym's server. Read tolerantly, like [GymButton].
class GymLogo {
  const GymLogo(this.bytes);

  final Uint8List bytes;

  static GymLogo? tryFromJson(Json json) {
    final b64 = _first(json, ['Base64', 'LogoBase64', 'Logo', 'Image']);
    if (b64 == null) return null;
    try {
      final bytes = base64Decode(b64);
      return bytes.isEmpty ? null : GymLogo(bytes);
    } on FormatException {
      return null;
    }
  }
}

String? _first(Json json, List<String> keys) {
  for (final key in keys) {
    if (asString(json[key]) case final value?) return value;
  }
  return null;
}

Uri? _webAddress(String? text) {
  final uri = text == null ? null : Uri.tryParse(text);
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty
      ? uri
      : null;
}
