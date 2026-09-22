import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:managevity/models/guest_pass.dart';
import 'package:managevity/models/profile_settings.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/services/demo_server.dart';
import 'package:managevity/services/sportivity_api.dart';
import 'package:managevity/utils/errors.dart';

// The real client against the in-app demo server: no fakes, the same code path a reviewer
// takes after typing demo / demo.
void main() {
  late SportivityApi api;

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  setUp(() async {
    api = SportivityApi();
    await api.login(DemoServer.user, DemoServer.password);
  });

  test('demo / demo signs in without touching the network', () {
    expect(api.isDemo, isTrue);
    expect(api.session?.token, DemoServer.token);
  });

  test('a restored demo session goes back to the demo, not to the real server', () async {
    final restarted = SportivityApi()..session = const Session(token: DemoServer.token);
    expect(restarted.isDemo, isTrue);
    expect((await restarted.locations()).single.name, 'Example Sports Centre');
  });

  test('signing out leaves the demo', () {
    api.session = null;
    expect(api.isDemo, isFalse);
  });

  test('there is a full week of lessons, and every screen has data', () async {
    final location = (await api.locations()).single.id;
    final week = await api.schedule(location, today(), today().add(const Duration(days: 7)));
    expect(week.length, greaterThan(30));
    expect(week.every((l) => l.trainer != null && l.room != null), isTrue);

    expect((await api.userContent()).customer.fullName, 'Robin Example');
    expect(await api.memberships(location), hasLength(1));
    expect(await api.addons(location), hasLength(2));
    expect(await api.news(location), isNotEmpty);
    expect(await api.heatmapDay(location, today()), hasLength(24));
    expect(await api.heatmapWeek(location), hasLength(21));
    expect(await api.invoices(location), hasLength(10));
    expect(await api.invoices(location, all: false), hasLength(1));
    expect((await api.invoicePdf(1000)).take(4), '%PDF'.codeUnits);
    expect(await api.contactInformationHtml(location), contains('1234 AB'));
  });

  test('booking and cancelling change what the server reports', () async {
    final location = (await api.locations()).single.id;
    final tomorrow = today().add(const Duration(days: 1));
    final lessons = await api.schedule(location, tomorrow, tomorrow.add(const Duration(days: 1)));
    final free = lessons.firstWhere((l) => !l.bookingStatus.isMine && !l.full && l.amount == null);

    expect((await api.joinLesson(free.id, location)).success, isTrue);
    expect((await api.lesson(free.id)).bookingStatus.isBooked, isTrue);
    final window = await api.bookedLessons(
      location,
      today(),
      today().add(const Duration(days: 56)),
    );
    expect(window.map((l) => l.id), contains(free.id));

    expect((await api.cancelLesson(free.id, location)).success, isTrue);
    expect((await api.lesson(free.id)).bookingStatus.isMine, isFalse);
  });

  test('a full class puts you on the waiting list', () async {
    final location = (await api.locations()).single.id;
    // Not a Sunday: the lunchtime class does not run then.
    var day = today().add(const Duration(days: 1));
    if (day.weekday == DateTime.sunday) day = day.add(const Duration(days: 1));
    final lessons = await api.schedule(location, day, day.add(const Duration(days: 1)));
    final full = lessons.firstWhere((l) => l.full && !l.bookingStatus.isMine);
    expect(full.canUseWaitingList, isTrue);

    expect((await api.joinLesson(full.id, location)).success, isTrue);
    expect((await api.lesson(full.id)).bookingStatus.isWaitingList, isTrue);
  });

  test('the paid workshop is only bought when asked to', () async {
    final location = (await api.locations()).single.id;
    var saturday = today();
    while (saturday.weekday != DateTime.saturday) {
      saturday = saturday.add(const Duration(days: 1));
    }
    final lessons = await api.schedule(location, saturday, saturday.add(const Duration(days: 1)));
    final workshop = lessons.firstWhere((l) => l.amount != null);

    final refused = await api.joinLesson(workshop.id, location);
    expect((refused.success, refused.needsPayment), (false, true));
    expect((await api.lesson(workshop.id)).bookingStatus.isMine, isFalse);

    expect((await api.joinLesson(workshop.id, location, buy: true)).success, isTrue);
  });

  test('history has past lessons, with their trainer on request', () async {
    final location = (await api.locations()).single.id;
    final past = await api.bookedLessons(
      location,
      today().subtract(const Duration(days: 365)),
      today(),
    );
    expect(past, isNotEmpty);
    expect((await api.lesson(past.first.id)).trainer, isNotNull);
  });

  test('profile, favourites and photo are remembered for the session', () async {
    final location = (await api.locations()).single.id;
    final lesson = (await api.schedule(
      location,
      today(),
      today().add(const Duration(days: 1)),
    )).first;
    await api.likeLesson(lesson.id, location, like: true);
    expect((await api.likedLessons(location)).map((l) => l.id), contains(lesson.id));

    expect(await api.customerPhoto(location), isNull);
    await api.uploadCustomerPhoto(location, Uint8List.fromList([1, 2, 3]));
    expect(await api.customerPhoto(location), [1, 2, 3]);
  });

  // Deliberately no test for "demo / wrong password": that is not the demo, so it would be
  // a real login attempt against the real server.
  test('the demo behaves like the real server on errors too', () async {
    await expectLater(
      api.lesson(-1),
      throwsA(isA<SportivityException>().having((e) => e.code, 'code', AppError.lessonNotFound)),
    );
  });

  test('guests can be signed up and removed', () async {
    final location = (await api.locations()).single.id;
    expect((await api.guestAllowance(location)).allowed, isTrue);
    await api.addGuest(location, NewGuest(name: 'Sam Guest', visitDate: today()));
    final guest = (await api.guestPasses(location)).single;
    expect(guest.name, 'Sam Guest');
    await api.deleteGuest(location, guest);
    expect(await api.guestPasses(location), isEmpty);
    await expectLater(
      api.addGuest(location, NewGuest(name: ' ', visitDate: today())),
      throwsA(isA<SportivityException>()),
    );
  });

  test('profile: language, opt-in and address lookup', () async {
    final location = (await api.locations()).single.id;
    await api.setLanguage(location, 'nl_NL');
    expect((await api.userContent()).customer.language, 'nl_NL');
    await api.setOptIn(location, const OptInSettings(whatsapp: true));
    expect((await api.optIn(location)).whatsapp, isTrue);
    expect((await api.countries(location)).where((c) => c.automaticAddress), isNotEmpty);
    expect(
      (await api.lookupAddress(location, zipCode: '1234 AB', houseNumber: 1))?.city,
      'Exampleton',
    );
  });

  test('payments: amounts to choose from, but nothing is ever paid in the demo', () async {
    final location = (await api.locations()).single.id;
    expect(await api.creditOptions(location), hasLength(4));
    await expectLater(api.paymentLink(location), throwsA(isA<SportivityException>()));
    await expectLater(api.creditLink(location, 10), throwsA(isA<SportivityException>()));
  });
}
