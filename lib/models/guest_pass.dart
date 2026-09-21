import '../utils/json.dart';

/// "Samen sporten" (bring a friend): a guest the customer has signed up.
class GuestPass {
  const GuestPass({
    required this.id,
    required this.name,
    this.email,
    this.visitDate,
    this.used = false,
  });

  final int id;
  final String name;
  final String? email;
  final DateTime? visitDate;
  final bool used;

  static GuestPass? tryFromJson(Json json) {
    final id = asInt(json['TogetherEntranceID']);
    if (id == null) return null;
    return GuestPass(
      id: id,
      name: asString(json['FullnameGuest']) ?? '',
      email: asString(json['EmailGuest']),
      visitDate: asDateTime(json['DateVisitGuest']),
      used: asBool(json['Used']),
    );
  }
}
