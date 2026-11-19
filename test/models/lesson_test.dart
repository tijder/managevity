import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/lesson.dart';

void main() {
  test('without an id or times it is not a lesson', () {
    expect(Lesson.tryFromJson({'Description': 'x'}), isNull);
    expect(Lesson.tryFromJson({'_id': 1, 'UTCStartTime': 'not a date', 'UTCEndTime': ''}), isNull);
  });

  test('numbers as strings and empty strings are tolerated', () {
    final lesson = Lesson.tryFromJson({
      'LessonId': '12',
      'Description': 'Pilates',
      'UTCStartTime': '2026-09-22T18:00:00.000Z',
      'UTCEndTime': '2026-09-22T19:00:00.000Z',
      'SpotsInt': '3',
      'Trainer': '  ',
      'Full': 'false',
    })!;
    expect(lesson.id, 12);
    expect(lesson.participants, 3);
    expect(lesson.trainer, isNull);
    expect(lesson.full, isFalse);
  });

  test('toJson → tryFromJson is lossless (the cache relies on this)', () {
    final original = Lesson.tryFromJson({
      '_id': 9,
      'Description': 'Bootcamp',
      'UTCStartTime': '2026-09-22T06:30:00Z',
      'UTCEndTime': '2026-09-22T07:30:00Z',
      'BookingStatus': 'Booked',
      'LocationID': 4,
      'Location': 'Outdoors',
      'Trainer': 'Sam',
      'LessonColor': '#FF8800',
      'LikedLesson': true,
      'CanUseWaitingList': true,
    })!;
    final copy = Lesson.tryFromJson(original.toJson())!;
    expect(copy.toJson(), original.toJson());
    expect(copy.startUtc.isUtc, isTrue);
  });

  // The real server answers in Dutch; the Dutch statuses below test that keyword matching.
  group('BookingStatus', () {
    test('the values the real server sends', () {
      expect(const BookingStatus('Gereserveerd').isBooked, isTrue);
      expect(const BookingStatus('Reservering_vast').isBooked, isTrue);
      expect(const BookingStatus('Aangemeld').isBooked, isTrue);
      expect(const BookingStatus('Aangemeld').isAttended, isTrue);
      expect(const BookingStatus('Gereserveerd').isAttended, isFalse);
      expect(const BookingStatus('Gereserveerd').isWaitingList, isFalse);
    });

    test('waiting list takes precedence over booked', () {
      expect(const BookingStatus('WaitingList').isWaitingList, isTrue);
      expect(const BookingStatus('Op wachtlijst').isBooked, isFalse);
      expect(const BookingStatus('Op wachtlijst').isMine, isTrue);
    });
    test('not booked is not booked', () {
      expect(const BookingStatus('NotBooked').isBooked, isFalse);
      expect(const BookingStatus('Niet geboekt').isMine, isFalse);
      expect(const BookingStatus('').isMine, isFalse);
    });
    test('booked', () {
      expect(const BookingStatus('Booked').isBooked, isTrue);
      expect(const BookingStatus('Geboekt').isBooked, isTrue);
    });
  });

  group('SpotsInt counts the people going, not the free spots', () {
    Lesson parse(Object spotsInt, Object max, {bool full = false}) => Lesson.tryFromJson({
      '_id': 1,
      'UTCStartTime': '2026-09-22T18:00:00Z',
      'UTCEndTime': '2026-09-22T19:00:00Z',
      'SpotsInt': spotsInt,
      'MaximumParticipants': max,
      'Full': full,
    })!;

    test('nobody booked yet: all spots free, not full', () {
      final lesson = parse(0, 14);
      expect((lesson.participants, lesson.spotsLeft, lesson.isFull), (0, 14, false));
    });

    test('some booked', () {
      final lesson = parse(18, 24);
      expect((lesson.participants, lesson.spotsLeft, lesson.isFull), (18, 6, false));
    });

    test('as many booked as the maximum: full (as the server says)', () {
      final lesson = parse(12, 12, full: true);
      expect((lesson.spotsLeft, lesson.isFull), (0, true));
    });

    test('without a maximum the free spots are unknown', () {
      final lesson = parse(3, '');
      expect((lesson.participants, lesson.spotsLeft, lesson.isFull), (3, null, false));
    });
  });

  group("the gym's own clock", () {
    Lesson parse(Object? local) => Lesson.tryFromJson({
      'LessonId': 1,
      'Description': 'Yoga',
      'UTCStartTime': '2026-09-22T17:00:00.000Z',
      'UTCEndTime': '2026-09-22T18:00:00.000Z',
      'LessonStartTime': local,
      'LessonEndTime': '2026-09-22 20:00:00',
    })!;

    test('is what the lesson shows, wherever the device is', () {
      // 19:00 on the wall of the gym, whatever TZ these tests run in.
      final lesson = parse('2026-09-22 19:00:00');
      expect(lesson.start.hour, 19);
      expect(lesson.start.day, 22);
      expect(lesson.end.hour, 20);
      // And it survives the offline cache.
      expect(Lesson.tryFromJson(lesson.toJson())!.start.hour, 19);
    });

    test('is ignored when it cannot be the same moment, or is missing', () {
      expect(parse('2026-09-25 19:00:00').start, DateTime.utc(2026, 9, 22, 17).toLocal());
      expect(parse('2026-09-22 19:07:00').start, DateTime.utc(2026, 9, 22, 17).toLocal());
      expect(parse(null).start, DateTime.utc(2026, 9, 22, 17).toLocal());
    });

    test('is handed on to the detailed lesson, which comes without it', () {
      final fromList = parse('2026-09-22 19:00:00');
      final detailed = parse(null);
      expect(detailed.keepingGymTimeOf(fromList).start.hour, 19);
    });
  });
}
