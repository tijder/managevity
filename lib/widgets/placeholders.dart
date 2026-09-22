import '../models/customer.dart';
import '../models/heatmap.dart';
import '../models/invoice.dart';
import '../models/lesson.dart';
import '../models/location.dart';
import '../models/membership.dart';
import '../models/news_item.dart';

// Fake data whose only job is to give the skeleton its shape while loading: Skeletonizer
// draws it as grey bars, the text itself is never readable. The lengths resemble real data,
// so the page does not jump when the content arrives.

Lesson _lesson(int i) {
  final start = DateTime.utc(2026, 1, 1, 8 + i * 2);
  return Lesson(
    id: -1 - i,
    description: const [
      'Bodypump basic',
      'Yoga flow',
      'Spinning 45 minutes',
      'Judo seniors',
    ][i % 4],
    startUtc: start,
    endUtc: start.add(const Duration(hours: 1)),
    bookingStatus: const BookingStatus(''),
    trainer: 'Firstname Lastname',
    room: 'Room number 1',
    locationName: 'Name of the location',
    activity: 'Activities',
    participants: 12,
    maximumParticipants: 24,
    additionalInformation:
        'A short description of the lesson that runs over two or three lines, so that the '
        'skeleton is roughly as tall as the real text will turn out.',
  );
}

final placeholderLessons = [for (var i = 0; i < 6; i++) _lesson(i)];
final placeholderLesson = _lesson(0);

const placeholderLocations = [
  Location(id: -1, name: 'Name of the location'),
  Location(id: -2, name: 'A second location'),
  Location(id: -3, name: 'Another location'),
];

final placeholderInvoices = [
  for (var i = 0; i < 8; i++)
    Invoice(
      id: -1 - i,
      number: '2026-0000$i',
      date: '01-0${i + 1}-2026',
      status: 'Settled',
      amount: '€ 00,00',
      amountValue: 0,
    ),
];

final placeholderNews = [
  for (var i = 0; i < 3; i++)
    NewsItem(
      title: 'Title of the message',
      date: DateTime.utc(2026),
      description:
          'A message from the gym that runs over a couple of lines and is only '
          'here to give the skeleton the right height while it is still loading.',
    ),
];

const placeholderMemberships = [
  Membership(
    id: -1,
    description: 'Name of the membership',
    locationName: 'Name of the location',
    active: true,
    amount: '€ 00,00 per month',
    unlimitedVisits: true,
    unlimitedReservations: true,
  ),
];

const placeholderUserContent = UserContent(
  customer: Customer(
    fullName: 'Firstname Lastname',
    email: 'email@example.org',
    address: 'Streetname',
    houseNumber: '00',
    zipCode: '0000 AA',
    city: 'Town name',
    phone: '0000000000',
    phoneMobile: '0600000000',
  ),
);

// Flat: a skeleton with made-up peaks would show a crowd that is not there, and the real
// bars have to move somewhere else afterwards anyway.
final placeholderHeatmapDay = [
  for (var hour = 0; hour < 24; hour++) HeatmapCell(hour: hour, value: 0),
];

final placeholderHeatmapWeek = [
  for (var day = 1; day <= 7; day++)
    for (var part = 1; part <= 3; part++) HeatmapCell(day: day, hour: part, value: 50),
];

const placeholderText =
    'A block of text of a couple of lines, with another line or so underneath.\n\n'
    'It is only here to give the skeleton the shape of the real content, and can '
    'never be read while loading.';
