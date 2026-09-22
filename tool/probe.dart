// Records how the API behaves in real life: the spec says nothing about the form of the
// Authorization header, the date formats or the fields in the `array<object>` responses.
//
//   SPORTIVITY_USER=… SPORTIVITY_PASSWORD=… dart run tool/probe.dart
//   (or the same two lines in .env — which is in .gitignore)
//
// Only reads: GETs, the login, and Location/LogoLocation (a POST that fetches a logo).
// Nothing is booked, changed or registered. Endpoints that
// could start something (Payment/*: a payment link may open a transaction) or that send
// data somewhere (IBANCheck) are deliberately left out.
//
// Output in probe-out/ (gitignored, contains personal data):
//   raw/<name>.json   the literal response
//   shapes.json       field names and types only, no values — this file is safe to
//                     share and is what the models and the fixtures are based on.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _base = 'https://www.sportivity.com/SportivityAppV3';

Future<void> main(List<String> args) async {
  final env = {...Platform.environment, ..._readDotEnv()};
  final user = env['SPORTIVITY_USER'];
  final password = env['SPORTIVITY_PASSWORD'];
  if (user == null || user.isEmpty || password == null || password.isEmpty) {
    stderr.writeln('Set SPORTIVITY_USER and SPORTIVITY_PASSWORD (env or .env).');
    exit(64);
  }

  final out = Directory('probe-out/raw')..createSync(recursive: true);
  final client = http.Client();
  final shapes = <String, Object?>{};
  // The status words are what the client has to recognize (booked / waiting list / …).
  final bookingStatuses = <String>{};
  shapes['_bookingStatuses'] = bookingStatuses;
  // Per endpoint, which statuses occur: "on the list of my lessons" versus "somewhere in
  // the schedule" tells booked apart from waiting list.
  final statusesBy = <String, Set<String>>{};
  shapes['_bookingStatusesBy'] = statusesBy;

  Future<Object?> record(String name, http.Response r) async {
    File('${out.path}/$name.json').writeAsStringSync(r.body);
    Object? body;
    try {
      body = jsonDecode(r.body);
    } on FormatException {
      body = null;
    }
    shapes[name] = {
      'status': r.statusCode,
      'contentType': r.headers['content-type'],
      'shape': body == null ? 'not JSON (${r.body.length} bytes)' : _shape(body),
      // The status texts themselves are what the client has to recognize; no personal data.
      if (body is Map && body['Response'] is String) 'responseText': body['Response'],
    };
    _collect(body, 'BookingStatus', bookingStatuses);
    _collect(body, 'BookingStatus', statusesBy.putIfAbsent(name, () => <String>{}));
    if (statusesBy[name]!.isEmpty) statusesBy.remove(name);
    stdout.writeln('${r.statusCode}  $name');
    return body;
  }

  final login = await client.post(
    Uri.parse('$_base/Login'),
    // Without Accept the server answers in XML.
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode({'User': user, 'Password': password, 'IsCallNaar2eOmgeving': false}),
  );
  final loginBody = await record('Login', login);
  final token = loginBody is Map ? loginBody['Token'] as String? : null;
  if (token == null || token.isEmpty) {
    stderr.writeln('No token in the login response; see probe-out/raw/Login.json');
    _writeShapes(shapes);
    exit(1);
  }

  // Which form of the header is accepted?
  String? authValue;
  for (final candidate in [token, 'Bearer $token']) {
    final r = await client.get(
      Uri.parse('$_base/UserContent'),
      headers: {'Authorization': candidate, 'Accept': 'application/json'},
    );
    final label = candidate == token ? 'bare' : 'Bearer';
    // A refused token arrives as HTTP 200 with `Response: "Wrong token"`.
    final rejected = r.body.toLowerCase().contains('wrong token');
    stdout.writeln(
      '${r.statusCode}  UserContent with Authorization=$label'
      '${rejected ? ' (Wrong token)' : ''}',
    );
    if (r.statusCode == 200 && !rejected && authValue == null) {
      authValue = candidate;
      shapes['_authorization'] = label;
    }
  }
  if (authValue == null) {
    stderr.writeln('None of the Authorization forms returned 200.');
    _writeShapes(shapes);
    exit(1);
  }
  final auth = {'Authorization': authValue, 'Accept': 'application/json'};

  Future<Object?> get(String name, String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    return record(name, await client.get(uri, headers: auth));
  }

  await get('UserContent', '/UserContent');
  final memberships = await get('CustomerMemberships', '/UserContent/CustomerMemberships');
  var locations = await get('Locations', '/Location/GetLocationsOfCompany');
  // GetLocationsOfCompany itself wants a LocationId; the memberships carry one.
  final membershipLocation = _firstLocationId(memberships);
  shapes['_locationsWithoutId'] = _firstLocationId(locations) != null;
  if (_firstLocationId(locations) == null && membershipLocation != null) {
    locations = await get('Locations_withId', '/Location/GetLocationsOfCompany', {
      'LocationId': '$membershipLocation',
    });
  }
  await get('CustomerAddons', '/AddOn/CustomerAddons');
  await get('News', '/News');
  await get('Notifications', '/Notifications');
  await get('Button', '/Button');
  await get('OptIn', '/OptIn');
  await get('Invoices', '/Invoices/GetInvoices');
  await get('Invoices_all', '/Invoices/GetInvoices', {'BooleanDefaultFalse': 'true'});
  await get('LikedLessons', '/Lesson/GetLikedLessons');
  await get('ContactInformation', '/HTML/ContactInformation');
  await get('Requirements', '/HTML/Requirements');

  final locationId = _firstLocationId(locations) ?? membershipLocation;
  shapes['_locationIdFound'] = locationId != null;
  if (locationId != null) {
    final now = DateTime.now();
    final end = now.add(const Duration(days: 7));
    // The date format is documented nowhere; try the common ones until one yields lessons.
    final formats = <String, String Function(DateTime)>{
      'yyyy-MM-dd': (d) => d.toIso8601String().substring(0, 10),
      'iso8601': (d) => d.toUtc().toIso8601String(),
      'dd-MM-yyyy': (d) =>
          '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}',
      'epochMillis': (d) => d.millisecondsSinceEpoch.toString(),
    };
    Object? ids;
    for (final entry in formats.entries) {
      ids = await get('LessonIds_${entry.key}', '/Lesson/GetIds', {
        'LocationId': '$locationId',
        'StartDate': entry.value(now),
        'EndDate': entry.value(end),
      });
      // The thin list can be empty while the rich one (LessonDefinitions) is full.
      final list = [
        for (final key in ['LessonIdsLists', 'LessonDefinitions'])
          if (ids is Map && ids[key] is List) ...ids[key] as List,
      ];
      if (list.isNotEmpty) {
        shapes['_dateFormat'] = entry.key;
        // A wide window, so that booked and waiting-list lessons show up with their status.
        await get('CustomerLessons', '/Lesson/GetCustomerLessons', {
          'LocationId': '$locationId',
          'StartDate': entry.value(now.subtract(const Duration(days: 30))),
          'EndDate': entry.value(now.add(const Duration(days: 56))),
        });
        final lessonId = _firstInt(list.first);
        if (lessonId != null) {
          await get('LessonById', '/Lesson/LessonById', {'LessonId': '$lessonId'});
        }
        break;
      }
    }
    await get('Heatmap', '/Heatmap', {'LocationId': '$locationId'});
    await get('HeatmapPerDay', '/Heatmap/PerDay', {'LocationId': '$locationId'});

    // ── The rest of the API, all read-only ──────────────────────────────────
    final loc = {'LocationId': '$locationId'};
    // These came back empty without a LocationId.
    await get('CustomerAddons_withId', '/AddOn/CustomerAddons', loc);
    await get('Button_withId', '/Button', loc);
    await get('OptIn_withId', '/OptIn', loc);

    await get('CreditOptions', '/Credits/GetCreditOptions', loc);
    await get('CancellationReasons', '/ChangeMembership/CancellationReasons', loc);
    await get('GuestPasses', '/TogetherEntrance', loc);
    await get('GuestCheckMembership', '/TogetherEntrance/CheckMembership', loc);
    await get('Countries', '/UserContent/Countries', loc);
    // A POST that only reads; without BundleIdentifier, as the app sends it.
    await record(
      'LogoLocation',
      await client.post(
        Uri.parse('$_base/Location/LogoLocation'),
        headers: {...auth, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'IsCallNaar2eOmgeving': false,
          'Flavour': '',
          'IsCallNaar4eOmgeving': false,
        }),
      ),
    );

    final content = await get('UserContent_withId', '/UserContent', loc);
    final customer = content is Map ? content['Customer'] : null;
    if (customer is Map) {
      final zip = customer['ZipCode'], number = _firstInt(customer['HouseNumber']);
      if (zip is String && zip.isNotEmpty && number != null) {
        await get('AddressValid', '/UserContent/AdressValid', {
          ...loc,
          'ZipCode': zip,
          'HouseNumber': '$number',
        });
      }
    }

    for (final language in ['nl', 'en']) {
      final definitions = await get(
        'MembershipDefinitions_$language',
        '/MembershipDefinition/MembershipDefinitions',
        {...loc, 'Language': language},
      );
      if (language != 'nl') continue;
      final list = definitions is Map ? definitions['MembershipDefinitions'] : null;
      final definitionId = list is List && list.isNotEmpty
          ? _firstIntOf(list.first, [
              'MembershipDefinitionId',
              'MembershipDefinitionID',
              'Id',
              '_id',
            ])
          : null;
      shapes['_membershipDefinitionIdFound'] = definitionId != null;
      if (definitionId != null) {
        final def = {...loc, 'Language': language, 'MembershipDefinitionId': '$definitionId'};
        final start = now.add(const Duration(days: 7)).toIso8601String().substring(0, 10);
        await get('MembershipConditions', '/MembershipDefinition/Conditions', def);
        await get('MembershipFirstCosts', '/MembershipDefinition/FirstCosts', {
          ...def,
          'StartDate': start,
          'IsAction': 'false',
          'UseNoDeposits': 'false',
        });
        await get('MembershipDefinitionAddons', '/MembershipDefinition/Addons', {
          ...def,
          'StartDate': start,
          'Promotion': 'false',
        });
      }
    }
    for (final type in ['GeneralConditions', 'PrivacyStatement', 'HouseRules']) {
      await get('ConditionByType_$type', '/MembershipDefinition/ConditionByType', {
        ...loc,
        'Language': 'nl',
        'ConditionType': type,
      });
    }

    final own = memberships is Map ? memberships['Memberships'] : null;
    if (own is List && own.isNotEmpty) {
      final membershipId = _firstIntOf(own.first, ['MembershipID', 'MembershipId']);
      if (membershipId != null) {
        await get('MembershipAddon', '/AddOn/MembershipAddon', {'MembershipId': '$membershipId'});
        await get('MembershipUpgrade', '/MembershipDefinition/Upgrade', {
          ...loc,
          'Language': 'nl',
          'MembershipId': '$membershipId',
        });
      }
    }
  }

  _writeShapes(shapes);
  client.close();
  stdout.writeln('\nDone. Share probe-out/shapes.json (no values), not the raw/ directory.');
}

void _writeShapes(Map<String, Object?> shapes) {
  File('probe-out/shapes.json').writeAsStringSync(
    JsonEncoder.withIndent('  ', (o) => o is Set ? o.toList() : o.toString()).convert(shapes),
  );
}

void _collect(Object? v, String key, Set<String> into) {
  if (v is List) {
    for (final item in v) {
      _collect(item, key, into);
    }
  } else if (v is Map) {
    if (v[key] is String) into.add(v[key] as String);
    for (final value in v.values) {
      _collect(value, key, into);
    }
  }
}

/// Field names and types, without values. For a list only the first element plus the length.
Object? _shape(Object? v) => switch (v) {
  null => 'null',
  bool() => 'bool',
  int() => 'int',
  double() => 'double',
  String s => _stringKind(s),
  List l => {'_list': l.length, '_item': l.isEmpty ? null : _shape(l.first)},
  Map m => {for (final e in m.entries) '${e.key}': _shape(e.value)},
  _ => v.runtimeType.toString(),
};

/// The kind of string is what matters (date format, html, empty), never the content.
String _stringKind(String s) {
  if (s.isEmpty) return 'string(empty)';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}').hasMatch(s)) {
    return 'string(iso8601${s.endsWith('Z') ? ' Z' : ''}, e.g. length ${s.length})';
  }
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return 'string(yyyy-MM-dd)';
  if (RegExp(r'^\d{2}-\d{2}-\d{4}').hasMatch(s)) return 'string(dd-MM-yyyy…)';
  if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(s)) return 'string(HH:mm…)';
  if (RegExp(r'^\d+$').hasMatch(s)) return 'string(digits)';
  if (s.contains('<') && s.contains('>')) return 'string(html)';
  if (RegExp(r'^#?[0-9a-fA-F]{6,8}$').hasMatch(s)) return 'string(colour)';
  return 'string';
}

int? _firstLocationId(Object? body) {
  if (body is! Map) return null;
  for (final v in body.values) {
    if (v is List && v.isNotEmpty) return _firstInt(v.first);
  }
  return null;
}

int? _firstIntOf(Object? v, List<String> keys) {
  if (v is! Map) return null;
  for (final key in keys) {
    final hit = _firstInt(v[key]);
    if (hit != null) return hit;
  }
  return null;
}

int? _firstInt(Object? v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  if (v is Map) {
    for (final key in ['LocationId', 'LocationID', 'LessonId', 'Id', '_id', 'id']) {
      final hit = _firstInt(v[key]);
      if (hit != null) return hit;
    }
  }
  return null;
}

Map<String, String> _readDotEnv() {
  final f = File('.env');
  if (!f.existsSync()) return {};
  return {
    for (final line in f.readAsLinesSync())
      if (line.contains('=') && !line.trimLeft().startsWith('#'))
        line.substring(0, line.indexOf('=')).trim(): line.substring(line.indexOf('=') + 1).trim(),
  };
}
