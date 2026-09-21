import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/services/calendar/calendar_sync_target.dart';
import 'package:managevity/services/calendar/ics_builder.dart';

void main() {
  final event = CalendarEvent(
    uid: 'lesson-42@managevity.g4d.nl',
    title: 'Yoga; gentle, with Anna',
    // Local time in, UTC out.
    startUtc: DateTime.utc(2026, 9, 22, 17, 30),
    endUtc: DateTime.utc(2026, 9, 22, 18, 30),
    location: 'Room 1',
    description: 'Café line\nSecond line \\ end',
  );

  test('writes UTC times and the fixed UID', () {
    final ics = buildIcs(event, now: DateTime.utc(2026, 9, 21, 8));
    expect(ics, contains('UID:lesson-42@managevity.g4d.nl\r\n'));
    expect(ics, contains('DTSTAMP:20260921T080000Z\r\n'));
    expect(ics, contains('DTSTART:20260922T173000Z\r\n'));
    expect(ics, contains('DTEND:20260922T183000Z\r\n'));
    expect(ics, contains('STATUS:CONFIRMED\r\n'));
    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
  });

  test('a non-UTC DateTime is converted, not copied literally', () {
    final local = DateTime.utc(2026, 1, 5, 9).toLocal();
    final ics = buildIcs(CalendarEvent(uid: 'u', title: 't', startUtc: local, endUtc: local));
    expect(ics, contains('DTSTART:20260105T090000Z'));
  });

  test('escapes text according to RFC 5545', () {
    final ics = buildIcs(event);
    expect(ics, contains(r'SUMMARY:Yoga\; gentle\, with Anna'));
    expect(ics, contains(r'DESCRIPTION:Café line\nSecond line \\ end'));
  });

  test('waiting list becomes TENTATIVE', () {
    final ics = buildIcs(
      CalendarEvent(
        uid: 'u',
        title: 't',
        startUtc: event.startUtc,
        endUtc: event.endUtc,
        tentative: true,
      ),
    );
    expect(ics, contains('STATUS:TENTATIVE'));
  });

  test('category, coordinates and reminder', () {
    final ics = buildIcs(
      CalendarEvent(
        uid: 'u',
        title: 'Judo, seniors',
        startUtc: event.startUtc,
        endUtc: event.endUtc,
        categories: const ['Judo'],
        geo: (52.1, 5.2),
        reminder: const Duration(minutes: 30),
      ),
    );
    expect(ics, contains('CATEGORIES:Judo\r\n'));
    expect(ics, contains('GEO:52.1;5.2\r\n'));
    expect(
      ics,
      contains(
        'BEGIN:VALARM\r\nACTION:DISPLAY\r\n'
        r'DESCRIPTION:Judo\, seniors'
        '\r\nTRIGGER:-PT30M\r\nEND:VALARM\r\nEND:VEVENT',
      ),
    );
  });

  test('without a reminder no VALARM', () {
    expect(buildIcs(event), isNot(contains('VALARM')));
  });

  test('an empty location and description are left out', () {
    final ics = buildIcs(
      CalendarEvent(
        uid: 'u',
        title: 't',
        startUtc: event.startUtc,
        endUtc: event.endUtc,
        location: '',
      ),
    );
    expect(ics, isNot(contains('LOCATION')));
    expect(ics, isNot(contains('DESCRIPTION')));
  });

  test('folds long lines at 75 octets without breaking a character', () {
    final folded = foldIcsLine('SUMMARY:${'é' * 100}');
    final lines = folded.split('\r\n');
    expect(lines.length, greaterThan(1));
    for (final line in lines) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
    expect(lines.skip(1).every((l) => l.startsWith(' ')), isTrue);
    // Unfolding gives back the original.
    expect(folded.replaceAll('\r\n ', ''), 'SUMMARY:${'é' * 100}');
  });
}
