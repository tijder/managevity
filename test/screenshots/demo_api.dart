import 'dart:typed_data';

import 'package:managevity/models/customer.dart';
import 'package:managevity/models/guest_pass.dart';
import 'package:managevity/models/heatmap.dart';
import 'package:managevity/models/invoice.dart';
import 'package:managevity/models/lesson.dart';
import 'package:managevity/models/membership.dart';
import 'package:managevity/models/news_item.dart';
import 'package:managevity/providers/lessons_provider.dart';

import '../fixtures/fixtures.dart';

/// A populated, entirely made-up gym for the screenshots.
class DemoApi extends FakeSportivityApi {
  DemoApi() : super(lessons: _lessons()) {
    final today = dayOf(DateTime.now());
    guests
      ..add(GuestPass(id: 1, name: 'Sam Porter', visitDate: today.add(const Duration(days: 2))))
      ..add(
        GuestPass(
          id: 2,
          name: 'Kim de Vries',
          visitDate: today.subtract(const Duration(days: 9)),
          used: true,
        ),
      );
  }

  static List<Lesson> _lessons() {
    final today = dayOf(DateTime.now());
    Lesson at(
      int id,
      int dayOffset,
      int hour,
      String name,
      String activity,
      String trainer,
      String room,
      String color, {
      String status = '',
      int spots = 8, // free
      int max = 20,
      bool waiting = false,
    }) => Lesson(
      id: id,
      description: name,
      startUtc: today.add(Duration(days: dayOffset, hours: hour)).toUtc(),
      endUtc: today.add(Duration(days: dayOffset, hours: hour + 1)).toUtc(),
      bookingStatus: BookingStatus(status),
      locationName: 'Example Sports Centre',
      room: room,
      activity: activity,
      trainer: trainer,
      color: color,
      participants: max - spots,
      maximumParticipants: max,
      full: spots == 0,
      canUseWaitingList: waiting,
      additionalInformation:
          '<p>A varied lesson for every level. Bring a towel and a water bottle.</p>'
          '<p>Room: $room</p>',
    );
    return [
      at(1, 0, 7, 'Outdoor bootcamp', 'Bootcamp', 'Sam Porter', 'Sports field', '#E4572E'),
      at(2, 0, 9, 'Yoga flow', 'Yoga', 'Anna Bell', 'Studio 2', '#7B9E89', status: 'Booked'),
      at(
        3,
        0,
        12,
        'Spinning 45',
        'Spinning',
        'Tom Baker',
        'Cycle studio',
        '#2E86AB',
        spots: 0,
        waiting: true,
      ),
      at(4, 0, 18, 'Bodypump', 'Strength', 'Lisa Fisher', 'Studio 1', '#F2A541', spots: 3),
      at(
        5,
        0,
        19,
        'Pilates',
        'Yoga',
        'Anna Bell',
        'Studio 2',
        '#7B9E89',
        status: 'WaitingList',
        spots: 0,
      ),
      at(6, 0, 20, 'Judo for adults', 'Judo', 'Ruben Smith', 'Dojo', '#5C4B99', spots: 20, max: 24),
      at(7, 2, 19, 'Bodypump', 'Strength', 'Lisa Fisher', 'Studio 1', '#F2A541', status: 'Booked'),
      at(8, 5, 20, 'Judo for adults', 'Judo', 'Ruben Smith', 'Dojo', '#5C4B99', status: 'Booked'),
      at(9, -12, 20, 'Judo for adults', 'Judo', 'Ruben Smith', 'Dojo', '#5C4B99', status: 'Booked'),
      at(10, -400, 19, 'Yoga flow', 'Yoga', 'Anna Bell', 'Studio 2', '#7B9E89', status: 'Booked'),
    ];
  }

  // The screenshots should show the rich variant, as after fetching the details.
  @override
  Future<List<Lesson>> bookedLessons(int locationId, DateTime from, DateTime to) async => [
    for (final l in lessons)
      if (l.bookingStatus.isMine && !l.start.isBefore(from) && l.start.isBefore(to)) l,
  ];

  @override
  Future<List<Lesson>> likedLessons(int locationId) async => [
    for (final l in lessons)
      if (l.id == 2 || l.id == 6) l.copyWith(liked: true),
  ];

  @override
  Future<UserContent> userContent({int? locationId}) async => const UserContent(
    companyName: 'Example Sports Centre',
    latitude: 52.1,
    longitude: 5.2,
    customer: Customer(
      fullName: 'Robin Example',
      firstName: 'Robin',
      email: 'robin@example.org',
      address: 'Station Road',
      houseNumber: '12',
      zipCode: '1234 AB',
      city: 'Exampleton',
      phoneMobile: '0600000000',
      balance: '€ 0.00',
      country: 'Netherlands',
      language: 'nl_NL',
    ),
  );

  @override
  Future<List<Membership>> memberships(int locationId) async => [
    Membership(
      id: 1,
      description: 'Unlimited',
      locationName: 'Example Sports Centre',
      active: true,
      amount: '€ 39.95 per 4 weeks',
      contractEndDate: DateTime(2027, 3, 1),
      unlimitedVisits: true,
      unlimitedReservations: true,
    ),
  ];

  @override
  Future<List<Addon>> addons(int locationId) async => const [
    Addon(id: 1, description: 'Sauna', membershipName: 'Unlimited', price: '€ 5.00', on: true),
    Addon(id: 2, description: 'Sports drink', membershipName: 'Unlimited', price: '€ 4.00'),
  ];

  @override
  Future<List<Invoice>> invoices(int locationId, {bool all = true}) async => [
    for (var i = 0; i < 9; i++)
      if (all || i == 0)
        Invoice(
          id: 100 - i,
          number: '${i < 8 ? 2026 : 2025}-${1900 - i * 210}',
          date: i < 8 ? '27-0${8 - i}-2026' : '30-12-2025',
          status: i == 0 ? 'Open' : 'Paid',
          amount: '€ 39.95',
          amountValue: 39.95,
          location: 'Example Sports Centre',
        ),
  ];

  @override
  Future<Uint8List> invoicePdf(int invoiceId) async => Uint8List(0);

  @override
  Future<List<NewsItem>> news(int locationId) async => [
    NewsItem(
      title: 'New opening hours',
      date: DateTime(2026, 9, 1),
      html: '<p>From October we are open until 18:00 on Sundays.</p>',
    ),
    NewsItem(
      title: 'Summer schedule is over',
      date: DateTime(2026, 8, 24),
      html: '<p>All lessons run according to the regular schedule again. See you soon!</p>',
    ),
  ];

  @override
  Future<List<NewsItem>> notifications(int locationId) async => const [];

  @override
  Future<List<HeatmapCell>> heatmapDay(int locationId, DateTime day) async => [
    for (var h = 0; h < 24; h++)
      HeatmapCell(
        hour: h,
        value: const [
          0,
          0,
          0,
          0,
          0,
          1,
          4,
          9,
          30,
          14,
          10,
          7,
          4,
          2,
          6,
          12,
          15,
          14,
          13,
          20,
          9,
          4,
          1,
          0,
        ][h].toDouble(),
      ),
  ];

  @override
  Future<List<HeatmapCell>> heatmapWeek(int locationId) async => [
    for (var d = 1; d <= 7; d++)
      for (var p = 1; p <= 3; p++)
        HeatmapCell(day: d, hour: p, value: ((d * 5 + p * 11) % 17 + (p == 3 ? 8 : 2)).toDouble()),
  ];

  @override
  Future<String?> requirementsHtml(int locationId) async =>
      '<ul><li>Bring a towel</li><li>Clean indoor shoes only</li><li>Put your weights back</li></ul>';
}
