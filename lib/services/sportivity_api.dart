import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/customer.dart';
import '../models/guest_pass.dart';
import '../models/heatmap.dart';
import '../models/invoice.dart';
import '../models/lesson.dart';
import '../models/location.dart';
import '../models/membership.dart';
import '../models/news_item.dart';
import '../models/session.dart';
import '../utils/errors.dart';
import '../utils/json.dart';
import 'demo_server.dart';

/// On web this points at the proxy in our own image (`/api`), because the API sends no
/// CORS headers. Everywhere else it goes direct.
const kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://www.sportivity.com/SportivityAppV3',
);

class SportivityException implements Exception {
  const SportivityException(this.code, {this.serverMessage, this.statusCode});

  final AppError code;

  /// What the server itself said about it, verbatim; null if it said nothing.
  final String? serverMessage;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  /// The server could not be reached: no connection, or (on web) the proxy saying the
  /// server behind it did not answer. Only then is showing the cached copy "offline"; a
  /// refused token or a server error is an error, not a reason to show stale data.
  bool get isUnreachable => code == AppError.network || const {502, 503, 504}.contains(statusCode);

  /// For logs and tests. On screen use `describeError`, which knows the language.
  @override
  String toString() => 'SportivityException(${code.name}, $statusCode): ${serverMessage ?? ''}';
}

/// Result of booking or cancelling: succeeded or not, along with the text from the API.
class BookingResult {
  const BookingResult({
    required this.success,
    this.message,
    this.lesson,
    this.needsPayment = false,
  });

  final bool success;
  final String? message;
  final Lesson? lesson;

  /// The lesson can only be bought individually; nothing has been charged yet.
  final bool needsPayment;
}

/// Client for the API behind the official app (`/rest-doc/SportivityAppV3`).
class SportivityApi {
  SportivityApi({Dio? dio, String baseUrl = kApiBase}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      // Without Accept the server answers in XML.
      ..headers['Accept'] = 'application/json'
      ..validateStatus = ((_) => true);
  }

  final Dio _dio;

  /// The adapter that really talks to the network; kept so a demo session can be left again.
  late final HttpClientAdapter _networkAdapter = _dio.httpClientAdapter;

  Session? _session;
  Session? get session => _session;

  /// Setting the demo session routes every request to the in-app [DemoServer]; any other
  /// session (or none) goes to the network. It hangs off the session on purpose: a demo
  /// session restored after an app restart must end up in the demo again, never at the
  /// real server with a made-up token.
  set session(Session? value) {
    _session = value;
    final demo = value?.token == DemoServer.token;
    if (demo && _dio.httpClientAdapter is! DemoServer) {
      _networkAdapter; // capture the real adapter before replacing it
      _dio.httpClientAdapter = DemoServer();
    } else if (!demo && _dio.httpClientAdapter is DemoServer) {
      _dio.httpClientAdapter = _networkAdapter;
    }
  }

  bool get isDemo => _dio.httpClientAdapter is DemoServer;

  /// Called when the server rejects the token; yields a fresh session or null.
  /// The request is then repeated exactly once.
  Future<Session?> Function()? onSessionExpired;

  /// The renewal in progress. Several requests that are refused at the same moment share
  /// it, instead of each logging in again (and each trying every [AuthScheme]).
  Future<Session?>? _renewing;

  Future<Session?> _renew(Session? refused) {
    // Refused with a token that has been replaced in the meantime: the new one is there.
    if (_session != null && !identical(_session, refused)) return Future.value(_session);
    // Mind the braces: see the whenComplete pitfall in CLAUDE.md.
    return _renewing ??= (onSessionExpired?.call() ?? Future<Session?>.value()).whenComplete(() {
      _renewing = null;
    });
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<Session> login(String user, String password) async {
    // The demo login never touches the network: app-store reviewers get a working app
    // without an account, and nobody's real gym sees a login attempt for "demo".
    if (user == DemoServer.user && password == DemoServer.password) {
      session = const Session(token: DemoServer.token);
      return _session!;
    }
    session = null; // make sure a previous demo session does not answer a real login
    final body = await _send(
      'POST',
      'Login',
      authenticated: false,
      data: {'User': user, 'Password': password, 'IsCallNaar2eOmgeving': false},
    );
    final token = asString(body['Token']);
    if (token == null) {
      throw SportivityException(
        AppError.loginFailed,
        serverMessage: asString(body['Message']),
        statusCode: asInt(body['HttpStatusCode']),
      );
    }
    // Which form of the header the server wants is documented nowhere: try them. A rejected
    // token comes back as HTTP 200 with an error message in the body, so the body decides.
    for (final scheme in AuthScheme.values) {
      final candidate = Session(token: token, scheme: scheme);
      final response = await _dio.get<Object?>(
        'UserContent',
        options: Options(headers: {'Authorization': candidate.headerValue}),
      );
      if (response.statusCode == 200 && !_isTokenRejected(_decode(response.data))) {
        return session = candidate;
      }
    }
    throw const SportivityException(AppError.tokenRejected);
  }

  /// Returns the server's message.
  Future<String?> forgotPassword(String user) async {
    final body = await _send('POST', 'ForgotPassword', authenticated: false, data: {'Name': user});
    if (!asBool(body['Succes'])) {
      throw SportivityException(AppError.requestFailed, serverMessage: asString(body['State']));
    }
    return asString(body['State']);
  }

  // ── Customer ──────────────────────────────────────────────────────────────

  Future<UserContent> userContent({int? locationId}) async =>
      UserContent.fromJson(await _get('UserContent', {'LocationId': locationId}));

  Future<void> setContactDetails(ContactDetails details) =>
      _send('POST', 'UserContent/SetUserContent', data: details.toJson());

  Future<void> setLanguage(int locationId, String language) =>
      _send('POST', 'UserContent/Language', data: {'LocationId': locationId, 'Language': language});

  Future<Uint8List?> customerPhoto(int locationId) async {
    final body = await _get('CustomerPhoto', {'LocationId': locationId});
    final b64 = asString(body['PhotoBase64']);
    return b64 == null ? null : base64Decode(b64);
  }

  /// Replaces the ID photo held by the gym. Returns the server's message.
  Future<String?> uploadCustomerPhoto(int locationId, Uint8List photo) async {
    final body = await _send(
      'POST',
      'CustomerPhoto',
      data: {'PhotoBase64': base64Encode(photo), 'LocationId': locationId},
    );
    if (!asBool(body['Succes'])) {
      throw SportivityException(AppError.requestFailed, serverMessage: asString(body['Response']));
    }
    return asString(body['Response']);
  }

  Future<List<Membership>> memberships(int locationId) async => _items(
    await _get('UserContent/CustomerMemberships', {'LocationId': locationId}),
    'Memberships',
    Membership.tryFromJson,
  );

  Future<List<Addon>> addons(int locationId) async => _items(
    await _get('AddOn/CustomerAddons', {'LocationId': locationId}),
    'AddOns',
    Addon.tryFromJson,
  );

  /// The locations the customer can go to.
  ///
  /// `GetLocationsOfCompany` itself wants a LocationId, and right after logging in there is
  /// none yet. The memberships do carry one: they supply the first location(s), and with
  /// those the rest of the company is requested.
  Future<List<Location>> locations({int? locationId}) async {
    final found = <int, Location>{};
    final said = <String>{};

    Future<void> ask(int? id) async {
      final body = await _get('Location/GetLocationsOfCompany', {'LocationId': id});
      if (asString(body['Response']) case final text?) said.add(text);
      for (final l in _items(body, 'Locationss', Location.tryFromJson)) {
        found[l.id] = l;
      }
    }

    await ask(locationId);
    if (found.isEmpty) {
      final body = await _get('UserContent/CustomerMemberships', const {});
      if (asString(body['Response']) case final text?) said.add(text);
      final own = <int, Location>{};
      for (final m in asList(body['Memberships'])) {
        final id = asInt(m['LocationId']);
        if (id != null) {
          own[id] = Location(id: id, name: asString(m['LocationName']) ?? '$id');
        }
      }
      for (final id in own.keys) {
        await ask(id);
      }
      // The names from the memberships fill in whatever the company did not return.
      for (final l in own.values) {
        found.putIfAbsent(l.id, () => l);
      }
    }
    if (found.isEmpty) {
      // Show what the server said; "no locations" without a reason cannot be debugged.
      throw SportivityException(
        AppError.noLocations,
        serverMessage: said.isEmpty ? null : said.join(' / '),
      );
    }
    return found.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  // ── Lessons ───────────────────────────────────────────────────────────────

  /// The schedule from [from] to [to]. The fat variant (LessonDefinitions) takes
  /// precedence; the thin list fills in whatever is missing from it.
  Future<List<Lesson>> schedule(int locationId, DateTime from, DateTime to) async {
    final body = await _get('Lesson/GetIds', {
      'LocationId': locationId,
      'StartDate': _date(from),
      'EndDate': _date(to),
    });
    final byId = <int, Lesson>{
      for (final l in _items(body, 'LessonIdsLists', Lesson.tryFromJson)) l.id: l,
      for (final l in _items(body, 'LessonDefinitions', Lesson.tryFromJson)) l.id: l,
    };
    return byId.values.toList()..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  Future<Lesson> lesson(int lessonId) async {
    final body = await _get('Lesson/LessonById', {'LessonId': lessonId});
    return Lesson.tryFromJson(body) ??
        (throw SportivityException(
          AppError.lessonNotFound,
          serverMessage: asString(body['Response']),
        ));
  }

  /// The lessons the customer is booked for (or on the waiting list for).
  Future<List<Lesson>> bookedLessons(int locationId, DateTime from, DateTime to) async {
    final body = await _get('Lesson/GetCustomerLessons', {
      'LocationId': locationId,
      'StartDate': _date(from),
      'EndDate': _date(to),
    });
    return _items(body, 'LessonIdsLists', Lesson.tryFromJson)
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  }

  Future<List<Lesson>> likedLessons(int locationId) async => _items(
    await _get('Lesson/GetLikedLessons', {'LocationId': locationId}),
    'LessonIdsLists',
    Lesson.tryFromJson,
  );

  /// [buy] charges for a single lesson and is therefore off by default. Without [buy] a
  /// paid lesson comes back as `needsPayment`, so that the UI can show the amount first.
  Future<BookingResult> joinLesson(int lessonId, int locationId, {bool buy = false}) async {
    final body = await _send(
      'POST',
      'Lesson/JoinLesson',
      data: {'LessonId': lessonId, 'LocationId': '$locationId', 'BuyLesson': buy},
    );
    return BookingResult(
      success: asBool(body['Succes']),
      message: asString(body['Response']),
      lesson: Lesson.tryFromJson(body),
      needsPayment: asBool(body['ShowFinancialPopup']),
    );
  }

  Future<BookingResult> cancelLesson(int lessonId, int locationId) async {
    final body = await _send(
      'POST',
      'Lesson/CancelLessonRequest',
      data: {'LessonId': lessonId, 'LocationId': '$locationId'},
    );
    return BookingResult(success: asBool(body['Succes']), message: asString(body['Response']));
  }

  Future<bool> likeLesson(int lessonId, int locationId, {required bool like}) async {
    final body = await _send(
      'POST',
      'Lesson/LikeLesson',
      data: {'LessonId': lessonId, 'LocationId': '$locationId', 'LikeBool': like},
    );
    return asBool(body['Succes']);
  }

  // ── Other ─────────────────────────────────────────────────────────────────

  Future<List<HeatmapCell>> heatmapWeek(int locationId) async => _items(
    await _get('Heatmap', {'LocationId': locationId}),
    'Heatmaps',
    HeatmapCell.tryFromJson,
  );

  Future<List<HeatmapCell>> heatmapDay(int locationId, DateTime day) async => _items(
    await _get('Heatmap/PerDay', {'LocationId': locationId, 'Date': _date(day)}),
    'Heatmap_24hs',
    HeatmapCell.tryFromJson,
  );

  Future<List<NewsItem>> news(int locationId) async =>
      _items(await _get('News', {'LocationId': locationId}), 'Newss', NewsItem.tryFromJson);

  Future<List<NewsItem>> notifications(int locationId) async => _items(
    await _get('Notifications', {'LocationId': locationId}),
    'Newss',
    NewsItem.tryFromJson,
  );

  /// `BooleanDefaultFalse` has no description in the spec; the partner API of the same
  /// platform calls the same flag `ShowAll`: false (the default) returns unpaid invoices
  /// only. Anyone who has paid everything then sees an empty list.
  Future<List<Invoice>> invoices(int locationId, {bool all = true}) async => _items(
    await _get('Invoices/GetInvoices', {'LocationId': locationId, 'BooleanDefaultFalse': all}),
    'Invoices',
    Invoice.tryFromJson,
  );

  Future<Uint8List> invoicePdf(int invoiceId) async {
    final body = await _get('Invoices/GetInvoicePDF', {'InvoiceId': invoiceId});
    final b64 = asString(body['PDFString']);
    if (b64 == null) {
      throw SportivityException(AppError.noPdf, serverMessage: asString(body['Response']));
    }
    return base64Decode(b64);
  }

  Future<String?> mailInvoice(int invoiceId) async =>
      asString((await _get('Invoices/ViaMail', {'InvoiceId': invoiceId}))['Response']);

  Future<String?> contactInformationHtml(int locationId) async =>
      asString((await _get('HTML/ContactInformation', {'LocationId': locationId}))['HTML']);

  Future<String?> requirementsHtml(int locationId) async =>
      asString((await _get('HTML/Requirements', {'LocationId': locationId}))['HTML']);

  Future<List<GuestPass>> guestPasses(int locationId) async => _items(
    await _get('TogetherEntrance', {'LocationId': locationId}),
    'TogetherEntranceApps',
    GuestPass.tryFromJson,
  );

  // ── Transport ─────────────────────────────────────────────────────────────

  Future<Json> _get(String path, Map<String, Object?> query) => _send('GET', path, query: query);

  Future<Json> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? data,
    bool authenticated = true,
    bool retried = false,
  }) async {
    // While a renewal runs there is no session (login clears it); wait for the new one
    // rather than failing with "not logged in".
    if (authenticated && _renewing != null) await _renewing;
    if (authenticated && session == null) {
      throw const SportivityException(AppError.notLoggedIn, statusCode: 401);
    }
    final sentWith = _session;
    final Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: {
          for (final e in (query ?? const <String, Object?>{}).entries)
            if (e.value != null) e.key: e.value,
        },
        options: Options(
          method: method,
          headers: {if (authenticated) 'Authorization': sentWith!.headerValue},
        ),
      );
    } on DioException {
      throw const SportivityException(AppError.network);
    }

    final body = _decode(response.data);
    // The server almost always answers with HTTP 200 and puts the real outcome in the
    // body: `HttpStatusCode` for the login, `Response: "Wrong token"` for everything else.
    var status = response.statusCode ?? 0;
    final bodyStatus = asInt(body['HttpStatusCode']);
    if (status == 200 && bodyStatus != null && bodyStatus >= 400) status = bodyStatus;
    if (authenticated && _isTokenRejected(body)) status = 401;

    if (authenticated && (status == 401 || status == 403) && !retried) {
      final fresh = await _renew(sentWith);
      if (fresh != null) {
        session = fresh;
        return _send(method, path, query: query, data: data, retried: true);
      }
    }
    if (status < 200 || status >= 300) {
      // To the user a rejected token ("Wrong token") simply means: not logged in.
      if (status == 401 || status == 403) {
        // Without a session this is the login itself: then the server's text ("Inloggegevens
        // onjuist", i.e. wrong credentials) is exactly what the user should see.
        throw authenticated
            ? SportivityException(AppError.notLoggedIn, statusCode: status)
            : SportivityException(
                AppError.loginFailed,
                serverMessage: asString(body['Message']) ?? asString(body['Response']),
                statusCode: status,
              );
      }
      throw SportivityException(
        AppError.server,
        serverMessage: asString(body['Response']) ?? asString(body['Message']),
        statusCode: status,
      );
    }
    return body;
  }

  bool _isTokenRejected(Json body) =>
      (asString(body['Response']) ?? '').toLowerCase().contains('wrong token');

  Json _decode(Object? data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } on FormatException {
        // Not JSON (e.g. an HTML error page from the proxy): treat it as an empty body.
      }
    }
    return const {};
  }

  List<T> _items<T extends Object>(Json body, String key, T? Function(Json) parse) =>
      asList(body[key]).map(parse).nonNulls.toList();

  /// TODO(probe): the date format of StartDate/EndDate/Date is not in the spec;
  /// tool/probe.dart establishes which format actually returns lessons.
  String _date(DateTime d) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${p(d.month)}-${p(d.day)}';
  }
}
