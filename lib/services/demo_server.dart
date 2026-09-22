import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A pretend server that lives inside the app, for the demo login (`demo` / `demo`).
///
/// App stores want reviewers to be able to try an app without a real account. This is a Dio
/// transport adapter, not a second API class: it answers the same JSON the real server
/// does, so a demo session runs through exactly the same client code, parsing and error
/// handling as a real one. Nothing leaves the device.
///
/// State (bookings, favourites, contact details, photo) lives in memory and resets when the
/// app restarts. Everything in here is made up.
class DemoServer implements HttpClientAdapter {
  static const user = 'demo';
  static const password = 'demo';

  /// The session token the demo login hands out; seeing it again after a restart is how
  /// the client knows to route to this server instead of the network.
  static const token = 'demo-session';

  static const _locationId = 1;
  static const _locationName = 'Example Sports Centre';

  final _booked = <int>{};
  final _waiting = <int>{};
  final _liked = <int>{};
  String? _photoBase64;
  final _guests = <Map<String, Object?>>[];
  var _language = 'en_GB';
  var _optIn = <String, Object?>{'OptIn': true, 'OptInCalls': false, 'OptInWhatsapp': false};
  var _nextGuestId = 1;
  var _contact = <String, Object?>{
    'Address': 'Station Road',
    'HouseNumber': '12',
    'Addition': '',
    'ZipCode': '1234 AB',
    'City': 'Exampleton',
    'Phone': '',
    'PhoneMobile': '0600000000',
  };

  DemoServer() {
    // A believable starting point: two bookings this week and a favourite.
    final today = _today();
    _booked
      ..add(_lessonId(today.add(const Duration(days: 1)), 3))
      ..add(_lessonId(today.add(const Duration(days: 3)), 5));
    _waiting.add(_lessonId(today.add(const Duration(days: 2)), 2));
    _liked.add(_lessonId(today.add(const Duration(days: 1)), 5));
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = requestStream == null
        ? const <int>[]
        : (await requestStream.toList()).expand((chunk) => chunk).toList();
    Map<String, dynamic> body = const {};
    if (bytes.isNotEmpty) {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map) body = decoded.cast<String, dynamic>();
    }
    // A real server is never instant; without a pause the loading states would be untestable
    // in the demo and the app would feel unlike the real thing.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final path = options.uri.path.split('/SportivityAppV3/').last.split('/api/').last;
    final reply = _route(options.method, path, options.uri.queryParameters, body, options.headers);
    return ResponseBody.fromString(
      jsonEncode(reply),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, Object?> _route(
    String method,
    String path,
    Map<String, String> query,
    Map<String, dynamic> body,
    Map<String, dynamic> headers,
  ) {
    if (path == 'Login') {
      final ok = body['User'] == user && body['Password'] == password;
      return ok
          ? {'Token': token, 'HttpStatusCode': 200, 'Message': 'OK'}
          : {'HttpStatusCode': 401, 'Message': 'Incorrect username or password'};
    }
    if (path == 'ForgotPassword') return {'Succes': true, 'State': 'Demo: no email is sent.'};

    // Like the real server: a bad token is HTTP 200 with this body.
    final auth = '${headers['Authorization'] ?? ''}';
    if (auth != token && auth != 'Bearer $token') return {'Response': 'Wrong token'};

    final lessonId = int.tryParse('${body['LessonId'] ?? query['LessonId'] ?? ''}');
    return switch ((method, path)) {
      ('GET', 'UserContent') => _userContent(),
      ('POST', 'UserContent/SetUserContent') => _setContact(body),
      ('GET', 'UserContent/CustomerMemberships') => _memberships(),
      ('GET', 'AddOn/CustomerAddons') => _addons(),
      ('GET', 'Location/GetLocationsOfCompany') => {
        'Response': 'OK',
        'Locationss': [
          {'LocationId': _locationId, 'NameLocation': _locationName},
        ],
      },
      ('GET', 'Lesson/GetIds') => _schedule(query),
      ('GET', 'Lesson/GetCustomerLessons') => _customerLessons(query),
      ('GET', 'Lesson/GetLikedLessons') => {
        'Response': 'OK',
        'LessonIdsLists': [for (final id in _liked) ?_lessonById(id, thin: true)],
      },
      ('GET', 'Lesson/LessonById') =>
        _lessonById(lessonId ?? -1) ?? {'Response': 'Lesson not found'},
      ('POST', 'Lesson/JoinLesson') => _join(lessonId, buy: body['BuyLesson'] == true),
      ('POST', 'Lesson/CancelLessonRequest') => _cancel(lessonId),
      ('POST', 'Lesson/LikeLesson') => _like(lessonId, body['LikeBool'] == true),
      ('GET', 'Heatmap') => _heatmapWeek(),
      ('GET', 'Heatmap/PerDay') => _heatmapDay(),
      ('GET', 'News') => _news(),
      ('GET', 'Notifications') => {'Response': 'OK', 'Newss': <Object>[]},
      ('GET', 'Invoices/GetInvoices') => _invoices(all: query['BooleanDefaultFalse'] == 'true'),
      ('GET', 'Invoices/GetInvoicePDF') => {'Response': 'OK', 'PDFString': _demoPdf},
      ('GET', 'Invoices/ViaMail') => {'Response': 'Demo: no email is sent.'},
      ('GET', 'HTML/ContactInformation') => {
        'Response': 'OK',
        'HTML':
            '<p>$_locationName</p><p>Station Road 1<br>1234 AB Exampleton</p>'
            '<p>Open every day from 7:00 to 22:00.</p>',
      },
      ('GET', 'HTML/Requirements') => {
        'Response': 'OK',
        'HTML':
            '<ul><li>Bring a towel</li><li>Clean indoor shoes only</li>'
            '<li>Put your weights back</li></ul>',
      },
      ('GET', 'CustomerPhoto') => {'Response': 'OK', 'Succes': true, 'PhotoBase64': _photoBase64},
      ('POST', 'CustomerPhoto') => _setPhoto(body),
      ('GET', 'TogetherEntrance') => {
        'Response': 'Succes',
        'Warning': false,
        'TogetherEntranceApps': _guests,
      },
      ('GET', 'TogetherEntrance/CheckMembership') => {'Response': 'Succes', 'Warning': false},
      ('POST', 'TogetherEntrance') => _guest(body),
      ('POST', 'UserContent/Language') => () {
        _language = '${body['Language']}';
        return {'Response': 'Succes'};
      }(),
      ('GET', 'OptIn') => {'Response': 'Succes', ..._optIn},
      ('GET', 'Credits/GetCreditOptions') => {
        'Response': 'Succes',
        'CreditOptions': [
          for (final amount in [5, 10, 20, 50])
            {'Amount': '€$amount', 'Info': '', 'OriginalAmount': amount},
        ],
      },
      // Nobody pays anything in the demo: the answer a real server gives when it refuses.
      ('GET', 'Payment/GetLink' || 'Payment/GetCreditLink' || 'Payment/GetCreditLinkSportCredit') =>
        {'Response': 'Demo: nothing is paid in the demo.', 'Warning': true},
      ('POST', 'OptIn') => () {
        _optIn = {
          for (final key in ['OptIn', 'OptInCalls', 'OptInWhatsapp']) key: body[key] == true,
        };
        return {'Response': 'Succes'};
      }(),
      ('GET', 'UserContent/Countries') => {
        'Response': 'Succes',
        'Countries': [
          {'Name': 'Belgium', 'AutomaticAdress': false},
          {'Name': 'Germany', 'AutomaticAdress': false},
          {'Name': 'Netherlands', 'AutomaticAdress': true},
        ],
      },
      // Every postcode in the demo is on Station Road, Exampleton.
      ('GET', 'UserContent/AdressValid') => {
        'Response': 'Succes',
        'Address': 'Station Road',
        'Housenumber': int.tryParse(query['HouseNumber'] ?? ''),
        'Zipcode': query['ZipCode'],
        'City': 'Exampleton',
      },
      _ => {'Response': 'Not available in the demo'},
    };
  }

  // ── Lessons ────────────────────────────────────────────────────────────────

  static const _templates = <(int, String, String, String, String, String, int)>[
    // hour, name, activity, trainer, room, colour, capacity
    (7, 'Outdoor bootcamp', 'Bootcamp', 'Sam Porter', 'Sports field', '#E4572E', 16),
    (9, 'Yoga flow', 'Yoga', 'Anna Bell', 'Studio 2', '#7B9E89', 20),
    (12, 'Spinning 45', 'Spinning', 'Tom Baker', 'Cycle studio', '#2E86AB', 18),
    (18, 'Bodypump', 'Strength', 'Lisa Fisher', 'Studio 1', '#F2A541', 24),
    (19, 'Pilates', 'Yoga', 'Anna Bell', 'Studio 2', '#7B9E89', 14),
    (20, 'Judo for adults', 'Judo', 'Ruben Smith', 'Dojo', '#5C4B99', 24),
    (20, 'Boxing workshop', 'Workshop', 'Sam Porter', 'Studio 1', '#B23A48', 12),
  ];

  /// The workshop is not part of the membership: booking it asks for payment first.
  static const _paidSlot = 6;

  /// The lunchtime class is always full, so the waiting list can be tried.
  static const _fullSlot = 2;

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int _dayNumber(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2024)).inDays;

  int _lessonId(DateTime day, int slot) => _dayNumber(day) * 10 + slot;

  Map<String, Object?>? _lessonById(int id, {bool thin = false}) {
    final slot = id % 10;
    if (id < 0 || slot >= _templates.length) return null;
    final day = DateTime.utc(2024).add(Duration(days: id ~/ 10));
    // The workshop only runs on Saturdays; there is no lunchtime class on Sundays.
    if (slot == _paidSlot && day.weekday != DateTime.saturday) return null;
    if (slot == _fullSlot && day.weekday == DateTime.sunday) return null;

    final (hour, name, activity, trainer, room, colour, capacity) = _templates[slot];
    final start = DateTime(day.year, day.month, day.day, hour);
    final taken = slot == _fullSlot ? capacity : (id * 7) % (capacity - 2);
    // SpotsInt counts the people going, not the free spots (see Lesson.participants).
    final going = (taken + (_booked.contains(id) ? 1 : 0)).clamp(0, capacity);
    final status = _booked.contains(id)
        ? 'Booked'
        : _waiting.contains(id)
        ? 'WaitingList'
        : 'NotBooked';
    return {
      'Response': 'OK',
      'LessonId': id,
      '_id': id,
      'Description': name,
      'BookingStatus': status,
      'LikedLesson': _liked.contains(id),
      'LocationName': _locationName,
      'LocationID': _locationId,
      'SpotsInt': going,
      'MaximumParticipants': capacity,
      'LessonColor': colour,
      'UTCStartTime': start.toUtc().toIso8601String(),
      'UTCEndTime': start.add(const Duration(hours: 1)).toUtc().toIso8601String(),
      if (!thin) ...{
        'Activity': activity,
        'Trainer': trainer,
        'Location': room,
        'Full': going >= capacity,
        'CanUseWaitingList': slot == _fullSlot,
        'AmountAsString': slot == _paidSlot ? '€ 7.50' : null,
        'AdditionalInformation':
            '<p>A varied class for every level. Bring a towel and a water bottle.</p>'
            '<p>Room: $room</p>',
      },
    };
  }

  Iterable<DateTime> _days(Map<String, String> query) sync* {
    final from = DateTime.tryParse(query['StartDate'] ?? '') ?? _today();
    final to = DateTime.tryParse(query['EndDate'] ?? '') ?? from.add(const Duration(days: 1));
    for (var day = DateTime(from.year, from.month, from.day); day.isBefore(to);) {
      yield day;
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }

  Map<String, Object?> _schedule(Map<String, String> query) => {
    'Response': 'OK',
    'LessonDefinitions': [
      for (final day in _days(query))
        for (var slot = 0; slot < _templates.length; slot++) ?_lessonById(_lessonId(day, slot)),
    ],
  };

  Map<String, Object?> _customerLessons(Map<String, String> query) {
    final days = _days(query).map(_dayNumber).toSet();
    // History: a few classes taken in the past, so that screen has something to show.
    final past = [
      for (final ago in const [2, 5, 9, 16, 23, 40])
        _lessonId(_today().subtract(Duration(days: ago)), ago.isEven ? 3 : 5),
    ];
    return {
      'Response': 'OK',
      'LessonIdsLists': [
        for (final id in {..._booked, ..._waiting, ...past})
          if (days.contains(id ~/ 10))
            ?(_lessonById(id, thin: true)
              ?..['BookingStatus'] = _waiting.contains(id) ? 'WaitingList' : 'Booked'),
      ],
    };
  }

  Map<String, Object?> _join(int? id, {required bool buy}) {
    final lesson = id == null ? null : _lessonById(id);
    if (id == null || lesson == null) return {'Succes': false, 'Response': 'Lesson not found'};
    if (id % 10 == _paidSlot && !buy) {
      return {
        ...lesson,
        'Succes': false,
        'ShowFinancialPopup': true,
        'Response': 'This class is not part of your membership.',
      };
    }
    if (lesson['Full'] == true) {
      _waiting.add(id);
      return {..._lessonById(id)!, 'Succes': true, 'Response': 'You are on the waiting list.'};
    }
    _booked.add(id);
    return {..._lessonById(id)!, 'Succes': true, 'Response': 'Booked (demo).'};
  }

  Map<String, Object?> _cancel(int? id) {
    final removed = _booked.remove(id) | _waiting.remove(id);
    return {'Succes': removed, 'Response': removed ? 'Cancelled (demo).' : 'No booking found.'};
  }

  Map<String, Object?> _like(int? id, bool like) {
    if (id == null) return {'Succes': false, 'Response': 'Lesson not found'};
    like ? _liked.add(id) : _liked.remove(id);
    return {'Succes': true, 'Response': 'OK'};
  }

  // ── Everything else ────────────────────────────────────────────────────────

  Map<String, Object?> _userContent() => {
    'Response': 'OK',
    'Companys': [
      {'Name': _locationName, 'Latitude': 52.0907, 'Longitude': 5.1214},
    ],
    'Customer': {
      'FullName': 'Robin Example',
      'FirstName': 'Robin',
      'LastName': 'Example',
      'Email': 'robin@example.org',
      'Saldo': '€ 0.00',
      'Country': 'Netherlands',
      'Language': _language,
      ..._contact,
    },
  };

  Map<String, Object?> _setContact(Map<String, dynamic> body) {
    _contact = {..._contact, ...body, 'HouseNumber': '${body['HouseNumber'] ?? ''}'};
    return {'Response': 'OK'};
  }

  Map<String, Object?> _setPhoto(Map<String, dynamic> body) {
    _photoBase64 = body['PhotoBase64'] as String?;
    return {'Succes': true, 'Response': 'Photo updated (demo).'};
  }

  Map<String, Object?> _guest(Map<String, dynamic> body) {
    if (body['Delete'] == true) {
      final before = _guests.length;
      _guests.removeWhere((g) => g['TogetherEntranceID'] == body['TogetherEntranceID']);
      final removed = _guests.length < before;
      return {
        'Succes': removed,
        'Response': removed ? 'Guest removed (demo).' : 'Guest not found.',
      };
    }
    final name = '${body['FullnameGuest'] ?? ''}'.trim();
    if (name.isEmpty) return {'Succes': false, 'Response': 'A guest needs a name.'};
    final id = _nextGuestId++;
    _guests.add({
      'TogetherEntranceID': id,
      'FullnameGuest': name,
      'EmailGuest': body['EmailGuest'],
      'MobilePhoneGuest': body['MobilePhoneGuest'],
      'DateVisitGuest': body['DateVisitGuest'],
    });
    return {'Succes': true, 'Response': 'Guest signed up (demo).', 'TogetherEntranceID': id};
  }

  Map<String, Object?> _memberships() => {
    'Response': 'OK',
    'Memberships': [
      {
        'MembershipID': 1,
        'Description': 'Unlimited',
        'LocationId': _locationId,
        'LocationName': _locationName,
        'MembershipActive': true,
        'AmountAsString': '€ 39.95 per 4 weeks',
        'ContractEndDate': DateTime(_today().year + 1, 3).toIso8601String(),
        'UnlimitedVisits': true,
        'UnlimitedReservations': true,
      },
    ],
  };

  Map<String, Object?> _addons() => {
    'Response': 'OK',
    'AddOns': [
      {
        'AddonID': 1,
        'Description': 'Sauna',
        'MembershipName': 'Unlimited',
        'NormalPriceText': '€ 5.00',
        'AddonOn': true,
      },
      {
        'AddonID': 2,
        'Description': 'Sports drink',
        'MembershipName': 'Unlimited',
        'NormalPriceText': '€ 4.00',
        'AddonOn': false,
      },
    ],
  };

  Map<String, Object?> _invoices({required bool all}) {
    final today = _today();
    String two(int v) => v.toString().padLeft(2, '0');
    return {
      'Response': 'OK',
      'Invoices': [
        for (var i = 0; i < (all ? 10 : 1); i++)
          () {
            final date = DateTime(today.year, today.month - i, 27);
            return {
              'InvoiceID': 1000 - i,
              'InvoiceNumber': '${date.year}-${1900 - i * 210}',
              'InvoiceDate': '${two(date.day)}-${two(date.month)}-${date.year}',
              'InvoiceStatus': i == 0 ? 'Open' : 'Paid',
              'InvoiceAmount': 39.95,
              'AmountAsString': '€ 39.95',
              'CompanyLocationInvoice': _locationName,
            };
          }(),
      ],
    };
  }

  Map<String, Object?> _news() => {
    'Response': 'OK',
    'Newss': [
      {
        'Title': 'New opening hours',
        'Date': _today().subtract(const Duration(days: 3)).toIso8601String(),
        'HTML': '<p>From next month we are open until 18:00 on Sundays.</p>',
      },
      {
        'Title': 'Welcome to the demo',
        'Date': _today().subtract(const Duration(days: 10)).toIso8601String(),
        'HTML':
            '<p>Everything you see here is made up. Book, cancel and favourite as much as you '
            'like; it all resets when the app restarts.</p>',
      },
    ],
  };

  static const _dayCurve = [
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
  ];

  Map<String, Object?> _heatmapDay() => {
    'Response': 'OK',
    'Heatmap_24hs': [
      for (var hour = 0; hour < 24; hour++) {'hour': hour, 'number': _dayCurve[hour]},
    ],
  };

  Map<String, Object?> _heatmapWeek() => {
    'Response': 'OK',
    'Heatmaps': [
      for (var day = 1; day <= 7; day++)
        for (var part = 1; part <= 3; part++)
          {
            'sortday': day,
            'sorttod': part,
            'number': (day * 5 + part * 11) % 17 + (part == 3 ? 8 : 2),
          },
    ],
  };

  /// A minimal, valid one-page PDF that says "Demo invoice".
  static final _demoPdf = base64Encode(
    utf8.encode(
      '%PDF-1.4\n'
      '1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
      '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
      '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 300 144]/Contents 4 0 R'
      '/Resources<</Font<</F1 5 0 R>>>>>>endobj\n'
      '4 0 obj<</Length 44>>stream\n'
      'BT /F1 18 Tf 40 70 Td (Demo invoice) Tj ET\n'
      'endstream endobj\n'
      '5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n'
      'trailer<</Root 1 0 R>>\n'
      '%%EOF\n',
    ),
  );
}
