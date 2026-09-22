import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:managevity/models/customer.dart';
import 'package:managevity/models/guest_pass.dart';
import 'package:managevity/models/lesson.dart';
import 'package:managevity/models/location.dart';
import 'package:managevity/models/membership.dart';
import 'package:managevity/models/membership_offer.dart';
import 'package:managevity/models/payment.dart';
import 'package:managevity/models/profile_settings.dart';
import 'package:managevity/models/session.dart';
import 'package:managevity/models/sync_settings.dart';
import 'package:managevity/services/cache_service.dart';
import 'package:managevity/services/credential_store.dart';
import 'package:managevity/services/settings_service.dart';
import 'package:managevity/services/sportivity_api.dart';

// All data here is made up; nothing in this repo comes from a real account.

Lesson lessonFixture({
  int id = 1,
  String description = 'Yoga',
  required DateTime start,
  String? status,

  /// Spots free, out of [max]; the API itself sends the number of people going.
  int? spots = 5,
  int max = 10,
  String? activity = 'Yoga',
  String? trainer = 'Anna',
  bool canUseWaitingList = false,
}) => Lesson(
  id: id,
  description: description,
  startUtc: start.toUtc(),
  endUtc: start.add(const Duration(hours: 1)).toUtc(),
  bookingStatus: BookingStatus(status ?? ''),
  activity: activity,
  trainer: trainer,
  room: 'Room 1',
  participants: spots == null ? null : max - spots,
  maximumParticipants: spots == null ? null : max,
  full: spots == 0,
  canUseWaitingList: canUseWaitingList,
);

/// Refuses every request: a method the fake does not override must fail in a test, never
/// quietly reach the real server with a made-up token.
class _NoNetwork implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => throw StateError('FakeSportivityApi does not fake ${options.method} ${options.path}');

  @override
  void close({bool force = false}) {}
}

class FakeSportivityApi extends SportivityApi {
  FakeSportivityApi({this.lessons = const [], this.loginError})
    : super(dio: Dio()..httpClientAdapter = _NoNetwork());

  List<Lesson> lessons;
  final SportivityException? loginError;
  final joined = <(int, bool)>[];

  /// How often the server was called; for tests that care about frugality.
  final scheduleCalls = <(DateTime, DateTime)>[];
  final lessonCalls = <int>[];
  final bookedCalls = <(DateTime, DateTime)>[];
  final cancelled = <int>[];

  @override
  Future<Session> login(String user, String password) async {
    if (loginError != null) throw loginError!;
    return session = const Session(token: 'fake');
  }

  @override
  Future<List<Location>> locations({int? locationId}) async => const [
    Location(id: 7, name: 'Downtown'),
  ];

  @override
  Future<List<Lesson>> schedule(int locationId, DateTime from, DateTime to) async {
    scheduleCalls.add((from, to));
    return [
      for (final l in lessons)
        if (!l.start.isBefore(from) && l.start.isBefore(to)) l,
    ];
  }

  /// Like the real API: the list is thin (no trainer, room or description).
  @override
  Future<List<Lesson>> bookedLessons(int locationId, DateTime from, DateTime to) async {
    bookedCalls.add((from, to));
    return [
      for (final l in lessons)
        if (l.bookingStatus.isMine && !l.start.isBefore(from) && l.start.isBefore(to))
          Lesson(
            id: l.id,
            description: l.description,
            startUtc: l.startUtc,
            endUtc: l.endUtc,
            bookingStatus: l.bookingStatus,
            locationName: l.locationName,
          ),
    ];
  }

  // No photo by default: the avatar falls back to the initials, and no test touches the network.
  Uint8List? photo;
  final uploadedPhotos = <Uint8List>[];

  @override
  Future<Uint8List?> customerPhoto(int locationId) async => photo;

  @override
  Future<String?> uploadCustomerPhoto(int locationId, Uint8List bytes) async {
    uploadedPhotos.add(bytes);
    photo = bytes;
    return null;
  }

  String? contactHtml =
      '<p>Example Sports Centre</p><p>Station Road 12<br>1234 AB Exampleton</p><p>Tel. 010-0000000</p>';

  @override
  Future<String?> contactInformationHtml(int locationId) async => contactHtml;

  @override
  Future<UserContent> userContent({int? locationId}) async => const UserContent(
    customer: Customer(fullName: 'Test Person', country: 'Netherlands', language: 'nl_NL'),
    latitude: 52.1,
    longitude: 5.2,
  );

  @override
  Future<Lesson> lesson(int lessonId) async {
    lessonCalls.add(lessonId);
    return lessons.firstWhere((l) => l.id == lessonId);
  }

  @override
  Future<BookingResult> joinLesson(int lessonId, int locationId, {bool buy = false}) async {
    joined.add((lessonId, buy));
    lessons = [
      for (final l in lessons)
        l.id == lessonId ? l.copyWith(bookingStatus: const BookingStatus('Booked')) : l,
    ];
    return const BookingResult(success: true, message: 'Booked');
  }

  final guests = <GuestPass>[];
  var guestAllowed = const GuestAllowance(allowed: true);

  @override
  Future<List<GuestPass>> guestPasses(int locationId) async => [...guests];

  @override
  Future<GuestAllowance> guestAllowance(int locationId) async => guestAllowed;

  @override
  Future<String?> addGuest(int locationId, NewGuest guest) async {
    guests.add(GuestPass(id: guests.length + 1, name: guest.name, visitDate: guest.visitDate));
    return 'Guest signed up';
  }

  @override
  Future<String?> deleteGuest(int locationId, GuestPass guest) async {
    guests.removeWhere((g) => g.id == guest.id);
    return 'Guest removed';
  }

  var optInSettings = const OptInSettings(email: true);
  final languages = <String>[];

  @override
  Future<OptInSettings> optIn(int locationId) async => optInSettings;

  @override
  Future<String?> setOptIn(int locationId, OptInSettings settings) async {
    optInSettings = settings;
    return 'Succes';
  }

  @override
  Future<String?> setLanguage(int locationId, String language) async {
    languages.add(language);
    return 'Succes';
  }

  @override
  Future<List<Country>> countries(int locationId) async => const [
    Country(name: 'Netherlands', automaticAddress: true),
  ];

  @override
  Future<AddressLookup?> lookupAddress(
    int locationId, {
    required String zipCode,
    required int houseNumber,
    String addition = '',
  }) async =>
      zipCode == '0000 XX' ? null : const AddressLookup(street: 'Station Road', city: 'Exampleton');

  var membershipList = <Membership>[
    const Membership(id: 1, description: 'Unlimited', active: true, unlimitedVisits: true),
  ];
  var addonList = <Addon>[];

  @override
  Future<List<Membership>> memberships(int locationId) async => [...membershipList];

  @override
  Future<List<Addon>> addons(int locationId) async => [...addonList];

  var offerList = const [
    MembershipOffer(id: 11, description: 'Off-peak', amount: '€ 24.95 per 4 weeks'),
    MembershipOffer(
      id: 12,
      description: 'Unlimited',
      amount: '€ 39.95 per 4 weeks',
      promotion: true,
    ),
  ];
  final pdfsRequested = <String>[];

  @override
  Future<List<MembershipOffer>> membershipOffers(int locationId, String language) async =>
      offerList;

  @override
  Future<List<MembershipOffer>> upgradeOffers(
    int locationId,
    String language,
    int membershipId,
  ) async => offerList.skip(1).toList();

  @override
  Future<OfferConditions> offerConditions(int locationId, String language, int offerId) async =>
      const OfferConditions(
        ibanRequired: true,
        conditions: [
          OfferCondition(
            type: 'GeneralTerms',
            text: 'I accept',
            linkText: 'general terms',
            hasPdf: true,
          ),
        ],
      );

  @override
  Future<FirstCosts> firstCosts(
    int locationId,
    String language,
    MembershipOffer offer, {
    required DateTime start,
  }) async => const FirstCosts(
    description: 'Until the end of the month',
    firstCosts: '€ 12.40',
    total: '€ 37.40',
    deposits: [(description: 'Registration fee', amount: '€ 25.00')],
  );

  @override
  Future<List<Addon>> offerAddons(
    int locationId,
    String language,
    MembershipOffer offer, {
    required DateTime start,
  }) async => const [];

  @override
  Future<Uint8List> conditionPdf(int locationId, String language, String type) async {
    pdfsRequested.add(type);
    return Uint8List(0);
  }

  /// ('freeze' | 'cancel' | 'withdraw', membership id, reason).
  final membershipChanges = <(String, int, Object?)>[];

  @override
  Future<List<CancellationReason>> cancellationReasons(int locationId) async => const [
    CancellationReason(id: 1, description: 'Moving house'),
    CancellationReason(id: 2, description: 'Too expensive'),
  ];

  @override
  Future<String?> freezeMembership(
    Membership membership, {
    required String reason,
    required DateTime from,
    required DateTime until,
  }) async {
    membershipChanges.add(('freeze', membership.id, reason));
    return 'Freeze requested';
  }

  @override
  Future<String?> cancelMembership(
    Membership membership, {
    required DateTime from,
    required CancellationReason reason,
  }) async {
    membershipChanges.add(('cancel', membership.id, reason.id));
    return 'Cancellation received';
  }

  @override
  Future<String?> withdrawMembership(
    Membership membership, {
    required DateTime from,
    required CancellationReason reason,
  }) async {
    membershipChanges.add(('withdraw', membership.id, reason.id));
    return 'Withdrawal received';
  }

  /// ('request' | 'confirm', add-on id, on).
  final addonCalls = <(String, int, bool)>[];

  @override
  Future<List<Addon>> membershipAddons(int membershipId) async => const [];

  @override
  Future<String?> requestAddonChange(
    Addon addon, {
    required bool on,
    required DateTime from,
  }) async {
    addonCalls.add(('request', addon.id, on));
    return 'From then on you pay ${addon.price} extra.';
  }

  @override
  Future<String?> confirmAddonChange(
    Addon addon, {
    required bool on,
    required DateTime from,
  }) async {
    addonCalls.add(('confirm', addon.id, on));
    addonList = [
      for (final a in addonList)
        a.id == addon.id ? Addon(id: a.id, description: a.description, price: a.price, on: on) : a,
    ];
    return 'Add-on changed';
  }

  /// What was asked for: ('invoices', null) or ('credit', amount).
  final paymentRequests = <(String, num?)>[];
  static final paymentPage = Uri.parse('https://pay.example.org/checkout');

  @override
  Future<List<CreditOption>> creditOptions(int locationId) async => const [
    CreditOption(label: '€10', amount: 10),
    CreditOption(label: '€20', amount: 20),
  ];

  @override
  Future<Uri> paymentLink(int locationId) async {
    paymentRequests.add(('invoices', null));
    return paymentPage;
  }

  @override
  Future<Uri> creditLink(int locationId, num amount, {bool sportCredits = false}) async {
    paymentRequests.add(('credit', amount));
    return paymentPage;
  }

  @override
  Future<BookingResult> cancelLesson(int lessonId, int locationId) async {
    cancelled.add(lessonId);
    lessons = [
      for (final l in lessons)
        l.id == lessonId ? l.copyWith(bookingStatus: const BookingStatus('')) : l,
    ];
    return const BookingResult(success: true);
  }
}

class FakeCredentialStore implements CredentialStore {
  FakeCredentialStore({this.session});

  Session? session;
  SportivityCredentials? login;
  CalDavCredentials? calDav;

  @override
  Future<SportivityCredentials?> readLogin() async => login;
  @override
  Future<void> writeLogin(SportivityCredentials credentials) async => login = credentials;
  @override
  Future<Session?> readSession() async => session;
  @override
  Future<void> writeSession(Session session) async => this.session = session;
  @override
  Future<CalDavCredentials?> readCalDav() async => calDav;
  @override
  Future<void> writeCalDav(CalDavCredentials credentials) async => calDav = credentials;
  @override
  Future<void> clearCalDav() async => calDav = null;
  @override
  Future<void> clearLogin() async {
    login = null;
    session = null;
  }
}

class FakeSettingsService extends SettingsService {
  FakeSettingsService({this.location = (7, 'Downtown')});

  (int, String)? location;
  SyncSettings sync = const SyncSettings();

  @override
  Future<(int, String)?> getLocation() async => location;
  @override
  Future<void> setLocation(int id, String name) async => location = (id, name);
  @override
  Future<void> clearLocation() async => location = null;
  @override
  Future<SyncSettings> getSync() async => sync;
  @override
  Future<void> setSync(SyncSettings settings) async => sync = settings;
}

class FakeCacheService extends CacheService {
  final _store = <String, List<Lesson>>{};

  @override
  Future<void> saveLessons(String key, List<Lesson> lessons) async => _store[key] = lessons;
  @override
  Future<List<Lesson>> loadLessons(String key) async => _store[key] ?? const [];
  final detailsByKey = <String, Map<int, CachedLesson>>{};

  @override
  Future<Map<int, CachedLesson>> loadDetails({String key = 'details'}) async => {
    ...?detailsByKey[key],
  };
  @override
  Future<void> saveDetails(Map<int, CachedLesson> d, {String key = 'details'}) async =>
      detailsByKey[key] = {...d};

  @override
  Future<void> clear() async {
    _store.clear();
    detailsByKey.clear();
  }
}

/// Tests run in a single isolate and have no app directory for a lock file.
Future<T?> noSyncLock<T>(Future<T> Function() action) => action();
