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
    expect(lesson.spotsLeft, 3);
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
}
