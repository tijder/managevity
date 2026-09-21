import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../../utils/errors.dart';
import 'calendar_sync_target.dart';
import 'ics_builder.dart';

/// Writes directly to a CalDAV server (Nextcloud and anything else that follows RFC 4791).
///
/// [baseUrl] is the DAV root (`https://cloud.example.org/remote.php/dav/`) or a bare server
/// URL; for the latter `/.well-known/caldav` is tried first and then `/remote.php/dav/`.
/// On web it is our own origin: the nginx proxy in the image serves `/remote.php/dav/` on
/// the same path, so that the hrefs in the responses stay valid.
class CalDavTarget implements CalendarSyncTarget {
  CalDavTarget({
    required String baseUrl,
    required String username,
    required String password,
    Dio? dio,
  }) : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..responseType = ResponseType.plain
      // Status codes are judged here ourselves (207, 404 on delete, 412 on put).
      ..validateStatus = ((_) => true)
      ..headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  final Uri _base;
  final Dio _dio;

  @override
  Future<List<CalendarInfo>> listCalendars() async {
    final root = await _findDavRoot();
    final principal = await _hrefProp(
      root,
      '<d:current-user-principal/>',
      'current-user-principal',
    );
    final home = await _hrefProp(principal, '<c:calendar-home-set/>', 'calendar-home-set');
    final doc = await _propfind(
      home,
      depth: 1,
      props:
          '<d:resourcetype/><d:displayname/><d:current-user-privilege-set/>'
          '<c:supported-calendar-component-set/>'
          '<x:calendar-color xmlns:x="http://apple.com/ns/ical/"/>',
    );

    final calendars = <CalendarInfo>[];
    for (final response in _all(doc, 'response')) {
      final isCalendar = _all(
        response,
        'resourcetype',
      ).expand((e) => _all(e, 'calendar')).isNotEmpty;
      if (!isCalendar) continue;

      final components = _all(response, 'comp').map((e) => e.getAttribute('name')).toSet();
      if (components.isNotEmpty && !components.contains('VEVENT')) continue;

      // No privilege set in the response = cannot be judged, so we show the calendar.
      final privileges = _all(response, 'current-user-privilege-set');
      if (privileges.isNotEmpty) {
        final names = privileges
            .expand((e) => _all(e, 'privilege'))
            .expand((e) => e.childElements)
            .map((e) => e.name.local)
            .toSet();
        if (!names.any({'write', 'write-content', 'bind', 'all'}.contains)) continue;
      }

      final href = _first(response, 'href')?.innerText.trim();
      if (href == null || href.isEmpty) continue;
      final url = home.resolve(href).toString();
      final name = _first(response, 'displayname')?.innerText.trim();
      calendars.add(
        CalendarInfo(
          id: url,
          name: (name == null || name.isEmpty) ? url : name,
          color: _first(response, 'calendar-color')?.innerText.trim(),
        ),
      );
    }
    return calendars;
  }

  @override
  Future<WrittenEvent> upsert(
    String calendarId,
    CalendarEvent event, {
    WrittenEvent? existing,
  }) async {
    final url = existing?.ref ?? _objectUrl(calendarId, event.uid);
    final body = buildIcs(event);

    Future<Response<String>> put(Map<String, String> precondition) => _dio.put<String>(
      url,
      data: body,
      options: Options(headers: {'Content-Type': 'text/calendar; charset=utf-8', ...precondition}),
    );

    var response = await put(switch (existing) {
      null => {'If-None-Match': '*'},
      WrittenEvent(etag: final etag?) => {'If-Match': etag},
      _ => const {},
    });
    // 412: the object already exists (index lost) or was modified elsewhere. The sync is
    // one-way and the lesson is the source of truth, so overwrite without a precondition.
    // This only ever touches an object with our own UID in its name.
    if (response.statusCode == 412) response = await put(const {});

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw CalendarSyncException(AppError.calendarFailed, statusCode: status, detail: 'PUT $url');
    }
    return WrittenEvent(ref: url, etag: response.headers.value('etag'));
  }

  @override
  Future<void> delete(String calendarId, WrittenEvent existing) async {
    final response = await _dio.delete<String>(existing.ref);
    final status = response.statusCode ?? 0;
    if (status == 404 || status == 410) return;
    if (status < 200 || status >= 300) {
      throw CalendarSyncException(
        AppError.calendarFailed,
        statusCode: status,
        detail: 'DELETE ${existing.ref}',
      );
    }
  }

  String _objectUrl(String calendarUrl, String uid) {
    final base = calendarUrl.endsWith('/') ? calendarUrl : '$calendarUrl/';
    final file = uid.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$base$file.ics';
  }

  Future<Uri> _findDavRoot() async {
    final candidates = <Uri>[
      _base,
      if (!_base.path.contains('/dav')) ...[
        _base.resolve('/.well-known/caldav'),
        _base.resolve('/remote.php/dav/'),
      ],
    ];
    int? lastStatus;
    for (final candidate in candidates) {
      final response = await _rawPropfind(
        candidate,
        depth: 0,
        props: '<d:current-user-principal/>',
      );
      lastStatus = response.statusCode;
      if (lastStatus == 207) return response.realUri;
      if (lastStatus == 401 || lastStatus == 403) {
        throw CalendarSyncException(AppError.calendarAuth, statusCode: lastStatus);
      }
    }
    throw CalendarSyncException(
      AppError.calendarNotFound,
      statusCode: lastStatus,
      detail: '$_base',
    );
  }

  Future<Uri> _hrefProp(Uri url, String props, String element) async {
    final doc = await _propfind(url, depth: 0, props: props);
    final href = _all(doc, element)
        .expand((e) => _all(e, 'href'))
        .map((e) => e.innerText.trim())
        .firstWhere((h) => h.isNotEmpty, orElse: () => '');
    if (href.isEmpty) {
      throw CalendarSyncException(AppError.calendarNotFound, detail: element);
    }
    return url.resolve(href);
  }

  Future<XmlDocument> _propfind(Uri url, {required int depth, required String props}) async {
    final response = await _rawPropfind(url, depth: depth, props: props);
    if (response.statusCode != 207) {
      throw CalendarSyncException(
        AppError.calendarFailed,
        statusCode: response.statusCode,
        detail: 'PROPFIND $url',
      );
    }
    try {
      return XmlDocument.parse(response.data ?? '');
    } on XmlException catch (e) {
      throw CalendarSyncException(AppError.calendarFailed, detail: '$url: ${e.message}');
    }
  }

  Future<Response<String>> _rawPropfind(Uri url, {required int depth, required String props}) =>
      _dio.requestUri<String>(
        url,
        data:
            '<?xml version="1.0" encoding="utf-8"?>'
            '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">'
            '<d:prop>$props</d:prop></d:propfind>',
        options: Options(
          method: 'PROPFIND',
          headers: {'Depth': '$depth', 'Content-Type': 'application/xml; charset=utf-8'},
        ),
      );

  // Servers pick their own prefixes (d:, D:, none); only the local name counts.
  Iterable<XmlElement> _all(XmlNode node, String local) =>
      node.descendantElements.where((e) => e.name.local == local);

  XmlElement? _first(XmlNode node, String local) => _all(node, local).firstOrNull;
}
