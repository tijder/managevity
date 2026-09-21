import '../utils/json.dart';

class Membership {
  const Membership({
    required this.id,
    required this.description,
    this.locationName,
    this.active = false,
    this.startDate,
    this.contractEndDate,
    this.accessEndDate,
    this.cancelledPerDate,
    this.lastVisit,
    this.amount,
    this.unlimitedVisits = false,
    this.visitsLeft,
    this.unlimitedReservations = false,
    this.reservationCreditsLeft,
    this.blocked = false,
    this.blockageText,
  });

  final int id;
  final String description;
  final String? locationName;
  final bool active;
  final DateTime? startDate;
  final DateTime? contractEndDate;
  final DateTime? accessEndDate;
  final DateTime? cancelledPerDate;
  final DateTime? lastVisit;
  final String? amount;
  final bool unlimitedVisits;
  final int? visitsLeft;
  final bool unlimitedReservations;
  final int? reservationCreditsLeft;
  final bool blocked;
  final String? blockageText;

  static Membership? tryFromJson(Json json) {
    final id = asInt(json['MembershipID']);
    if (id == null) return null;
    return Membership(
      id: id,
      description: asString(json['Description']) ?? '$id',
      locationName: asString(json['LocationName']),
      active: asBool(json['MembershipActive']),
      startDate: asDateTime(json['StartDate']),
      contractEndDate: asDateTime(json['ContractEndDate']),
      accessEndDate: asDateTime(json['AccessEndDate']),
      cancelledPerDate: asDateTime(json['CancelledPerDate']),
      lastVisit: asDateTime(json['LastVisit']),
      amount: asString(json['AmountAsString']),
      unlimitedVisits: asBool(json['UnlimitedVisits']),
      visitsLeft: asInt(json['NumberOfVisitsLeft']),
      unlimitedReservations: asBool(json['UnlimitedReservations']),
      reservationCreditsLeft: asInt(json['ReservationCreditsLeft']),
      blocked: asBool(json['Blocked']) || asBool(json['ActiveBlockages']),
      blockageText: asBool(json['ShowBlockageText']) ? asString(json['BlockageText']) : null,
    );
  }
}

class Addon {
  const Addon({
    required this.id,
    required this.description,
    this.membershipName,
    this.on = false,
    this.mandatory = false,
    this.price,
    this.expirationDate,
    this.unlimitedVisits = false,
    this.visitsLeft,
  });

  final int id;
  final String description;
  final String? membershipName;
  final bool on;
  final bool mandatory;
  final String? price;
  final String? expirationDate;
  final bool unlimitedVisits;
  final int? visitsLeft;

  static Addon? tryFromJson(Json json) {
    final id = asInt(json['AddonID']);
    if (id == null) return null;
    return Addon(
      id: id,
      description: asString(json['Description']) ?? '$id',
      membershipName: asString(json['MembershipName']),
      on: asBool(json['AddonOn']),
      mandatory: asBool(json['Mandatory']),
      price: asString(json['NormalPriceText']),
      expirationDate: asString(json['ExperationDate']),
      unlimitedVisits: asBool(json['UnlimitedVisits']),
      visitsLeft: asInt(json['VisitsLeft']),
    );
  }
}
