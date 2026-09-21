/// Fishes a postal address out of the gym's free-form contact text; the API has no field
/// for it. The anchor is the Dutch postcode (`1234 AB`): the line it appears on, plus the
/// line above it if the postcode comes first on its line (then that line is the street).
/// A postcode only counts if a place name follows it; that way "opgericht in 1987 AD"
/// ("founded in 1987 AD") is not an address. Null if nothing is found — better no address
/// than a made-up one.
String? extractAddress(String text) {
  final lines = [
    for (final l in text.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  final postcode = RegExp(r'\b[1-9]\d{3}\s?[A-Z]{2}\s+\p{L}', unicode: true);
  for (var i = 0; i < lines.length; i++) {
    final match = postcode.firstMatch(lines[i]);
    if (match == null) continue;
    final line = _stripLabel(lines[i]);
    final startsWithPostcode = postcode.matchAsPrefix(line) != null;
    if (startsWithPostcode && i > 0 && RegExp(r'\d').hasMatch(lines[i - 1])) {
      return '${_stripLabel(lines[i - 1])}, $line';
    }
    return line;
  }
  return null;
}

String _stripLabel(String line) =>
    line.replaceFirst(RegExp(r'^(bezoek)?adres\s*:\s*', caseSensitive: false), '').trim();
