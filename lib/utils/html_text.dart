/// The API supplies contact details, house rules and news as HTML. A webview is too heavy
/// for that (and does not exist on Linux); plain text that keeps the paragraphs is enough.
String htmlToText(String html) {
  var s = html
      .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), '')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</(p|div|h[1-6]|tr)>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  // A non-breaking space is pointless in plain text and breaks searching and comparing.
  s = decodeHtmlEntities(s).replaceAll('\u00A0', ' ');
  return s.split('\n').map((l) => l.trim()).join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// `&eacute;`, `&#233;` and `&#xE9;` → é. Unknown names are left exactly as they are.
String decodeHtmlEntities(String s) =>
    s.replaceAllMapped(RegExp(r'&(#[xX][0-9a-fA-F]+|#\d+|[A-Za-z][A-Za-z0-9]*);'), (m) {
      final body = m[1]!;
      final code = body.startsWith('#')
          ? int.tryParse(
              body.substring(body[1] == 'x' || body[1] == 'X' ? 2 : 1),
              radix: body[1] == 'x' || body[1] == 'X' ? 16 : 10,
            )
          : _namedEntities[body];
      if (code == null || code <= 0 || code > 0x10FFFF) return m[0]!;
      return String.fromCharCode(code);
    });

/// Latin-1 plus the common typographic characters: what occurs in European running text.
const _namedEntities = <String, int>{
  'apos': 0x27,
  'AElig': 0xC6,
  'Aacute': 0xC1,
  'Acirc': 0xC2,
  'Agrave': 0xC0,
  'Aring': 0xC5,
  'Atilde': 0xC3,
  'Auml': 0xC4,
  'Ccedil': 0xC7,
  'ETH': 0xD0,
  'Eacute': 0xC9,
  'Ecirc': 0xCA,
  'Egrave': 0xC8,
  'Euml': 0xCB,
  'Iacute': 0xCD,
  'Icirc': 0xCE,
  'Igrave': 0xCC,
  'Iuml': 0xCF,
  'Ntilde': 0xD1,
  'OElig': 0x152,
  'Oacute': 0xD3,
  'Ocirc': 0xD4,
  'Ograve': 0xD2,
  'Oslash': 0xD8,
  'Otilde': 0xD5,
  'Ouml': 0xD6,
  'Scaron': 0x160,
  'THORN': 0xDE,
  'Uacute': 0xDA,
  'Ucirc': 0xDB,
  'Ugrave': 0xD9,
  'Uuml': 0xDC,
  'Yacute': 0xDD,
  'Yuml': 0x178,
  'aacute': 0xE1,
  'acirc': 0xE2,
  'acute': 0xB4,
  'aelig': 0xE6,
  'agrave': 0xE0,
  'amp': 0x26,
  'aring': 0xE5,
  'atilde': 0xE3,
  'auml': 0xE4,
  'bdquo': 0x201E,
  'brvbar': 0xA6,
  'bull': 0x2022,
  'ccedil': 0xE7,
  'cedil': 0xB8,
  'cent': 0xA2,
  'copy': 0xA9,
  'curren': 0xA4,
  'dagger': 0x2020,
  'deg': 0xB0,
  'divide': 0xF7,
  'eacute': 0xE9,
  'ecirc': 0xEA,
  'egrave': 0xE8,
  'eth': 0xF0,
  'euml': 0xEB,
  'euro': 0x20AC,
  'frac12': 0xBD,
  'frac14': 0xBC,
  'frac34': 0xBE,
  'gt': 0x3E,
  'hellip': 0x2026,
  'iacute': 0xED,
  'icirc': 0xEE,
  'iexcl': 0xA1,
  'igrave': 0xEC,
  'iquest': 0xBF,
  'iuml': 0xEF,
  'laquo': 0xAB,
  'ldquo': 0x201C,
  'lsquo': 0x2018,
  'lt': 0x3C,
  'macr': 0xAF,
  'mdash': 0x2014,
  'micro': 0xB5,
  'middot': 0xB7,
  'nbsp': 0xA0,
  'ndash': 0x2013,
  'not': 0xAC,
  'ntilde': 0xF1,
  'oacute': 0xF3,
  'ocirc': 0xF4,
  'oelig': 0x153,
  'ograve': 0xF2,
  'ordf': 0xAA,
  'ordm': 0xBA,
  'oslash': 0xF8,
  'otilde': 0xF5,
  'ouml': 0xF6,
  'para': 0xB6,
  'permil': 0x2030,
  'plusmn': 0xB1,
  'pound': 0xA3,
  'quot': 0x22,
  'raquo': 0xBB,
  'rdquo': 0x201D,
  'reg': 0xAE,
  'rsquo': 0x2019,
  'sbquo': 0x201A,
  'scaron': 0x161,
  'sect': 0xA7,
  'shy': 0xAD,
  'sup1': 0xB9,
  'sup2': 0xB2,
  'sup3': 0xB3,
  'szlig': 0xDF,
  'thorn': 0xFE,
  'times': 0xD7,
  'trade': 0x2122,
  'uacute': 0xFA,
  'ucirc': 0xFB,
  'ugrave': 0xF9,
  'uml': 0xA8,
  'uuml': 0xFC,
  'yacute': 0xFD,
  'yen': 0xA5,
  'yuml': 0xFF,
};
