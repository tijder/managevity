import 'calendar_sync_target.dart';

const _prodId = '-//g4d.nl//Managevity//NL';

/// Builds a single VCALENDAR with a single VEVENT (RFC 5545). Times go out as UTC: the
/// API supplies UTCStartTime/UTCEndTime, and this way no VTIMEZONE is needed.
String buildIcs(CalendarEvent event, {DateTime? now}) {
  final stamp = _utc(now ?? DateTime.now());
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:$_prodId',
    'CALSCALE:GREGORIAN',
    'BEGIN:VEVENT',
    'UID:${event.uid}',
    'DTSTAMP:$stamp',
    'DTSTART:${_utc(event.startUtc)}',
    'DTEND:${_utc(event.endUtc)}',
    'SUMMARY:${escapeIcsText(event.title)}',
    if (event.location != null && event.location!.isNotEmpty)
      'LOCATION:${escapeIcsText(event.location!)}',
    if (event.description != null && event.description!.isNotEmpty)
      'DESCRIPTION:${escapeIcsText(event.description!)}',
    if (event.categories.isNotEmpty) 'CATEGORIES:${event.categories.map(escapeIcsText).join(',')}',
    if (event.geo case (final lat, final lon)) 'GEO:$lat;$lon',
    'STATUS:${event.tentative ? 'TENTATIVE' : 'CONFIRMED'}',
    'TRANSP:OPAQUE',
    if (event.reminder case final reminder?) ...[
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${escapeIcsText(event.title)}',
      'TRIGGER:-PT${reminder.inMinutes}M',
      'END:VALARM',
    ],
    'END:VEVENT',
    'END:VCALENDAR',
  ];
  return '${lines.map(foldIcsLine).join('\r\n')}\r\n';
}

String _utc(DateTime d) {
  final u = d.toUtc();
  String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
  return '${p(u.year, 4)}${p(u.month)}${p(u.day)}T${p(u.hour)}${p(u.minute)}${p(u.second)}Z';
}

/// RFC 5545 §3.3.11: escape backslash, semicolon and comma, line endings become `\n`.
String escapeIcsText(String s) => s
    .replaceAll('\\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\n');

/// RFC 5545 §3.1: fold lines longer than 75 octets with CRLF + space. Counting is done in
/// UTF-8 octets and a line is never broken in the middle of a character.
String foldIcsLine(String line) {
  final out = StringBuffer();
  var octets = 0;
  for (final rune in line.runes) {
    final size = rune < 0x80
        ? 1
        : rune < 0x800
        ? 2
        : rune < 0x10000
        ? 3
        : 4;
    if (octets + size > 75) {
      out.write('\r\n ');
      octets = 1; // the space of the continuation line counts too
    }
    out.writeCharCode(rune);
    octets += size;
  }
  return out.toString();
}
