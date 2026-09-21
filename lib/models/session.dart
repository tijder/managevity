import '../utils/json.dart';

/// The spec does not say whether the token belongs in `Authorization` bare or as Bearer;
/// that is found out by trial at login and remembered here.
enum AuthScheme { raw, bearer }

class Session {
  const Session({required this.token, this.scheme = AuthScheme.raw});

  final String token;
  final AuthScheme scheme;

  String get headerValue => scheme == AuthScheme.bearer ? 'Bearer $token' : token;

  Json toJson() => {'token': token, 'scheme': scheme.name};

  static Session? tryFromJson(Json json) {
    final token = asString(json['token']);
    if (token == null) return null;
    return Session(
      token: token,
      scheme: AuthScheme.values.asNameMap()[json['scheme']] ?? AuthScheme.raw,
    );
  }
}
