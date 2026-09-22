import '../utils/json.dart';

/// "Samen sporten" (bring a friend): a guest the customer has signed up.
///
/// The shape of an item has not been seen in real data yet (no guests on the probe
/// account); the fields follow the request that creates one (`TogetherEntranceApp_2`).
class GuestPass {
  const GuestPass({
    required this.id,
    required this.name,
    this.email,
    this.mobile,
    this.visitDate,
    this.used = false,
  });

  final int id;
  final String name;
  final String? email;
  final String? mobile;
  final DateTime? visitDate;
  final bool used;

  static GuestPass? tryFromJson(Json json) {
    final id = asInt(json['TogetherEntranceID']);
    if (id == null) return null;
    return GuestPass(
      id: id,
      name: asString(json['FullnameGuest']) ?? '',
      email: asString(json['EmailGuest']),
      mobile: asString(json['MobilePhoneGuest']),
      visitDate: asDateTime(json['DateVisitGuest']),
      used: asBool(json['Used']),
    );
  }
}

/// Whether guests can be brought along now. The server answers `CheckMembership` with
/// `Warning: true` and the reason ("no duo membership with visits left") when not.
class GuestAllowance {
  const GuestAllowance({required this.allowed, this.message});

  final bool allowed;
  final String? message;
}

/// A guest to sign up.
class NewGuest {
  const NewGuest({required this.name, required this.visitDate, this.email = '', this.mobile = ''});

  final String name;
  final String email;
  final String mobile;
  final DateTime visitDate;
}
