import 'dart:typed_data';

import 'package:managevity/models/customer.dart';
import 'package:managevity/models/lesson.dart';
import 'package:managevity/models/location.dart';
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

class FakeSportivityApi extends SportivityApi {
  FakeSportivityApi({this.lessons = const [], this.loginError});

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
    customer: Customer(fullName: 'Test Person'),
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
