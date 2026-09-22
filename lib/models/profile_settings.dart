import '../utils/json.dart';

/// Which messages the gym may send (`OptIn`). Seen in real data: three flags.
class OptInSettings {
  const OptInSettings({this.email = false, this.calls = false, this.whatsapp = false});

  final bool email;
  final bool calls;
  final bool whatsapp;

  factory OptInSettings.fromJson(Json json) => OptInSettings(
    email: asBool(json['OptIn']),
    calls: asBool(json['OptInCalls']),
    whatsapp: asBool(json['OptInWhatsapp']),
  );

  OptInSettings copyWith({bool? email, bool? calls, bool? whatsapp}) => OptInSettings(
    email: email ?? this.email,
    calls: calls ?? this.calls,
    whatsapp: whatsapp ?? this.whatsapp,
  );

  Json toJson(int locationId) => {
    'OptIn': email,
    'LocationId': locationId,
    'OptInCalls': calls,
    'OptInWhatsapp': whatsapp,
  };
}

/// A country the gym knows. [automaticAddress]: street and city can be looked up from the
/// postcode and house number (`UserContent/AdressValid`).
class Country {
  const Country({required this.name, this.automaticAddress = false});

  final String name;
  final bool automaticAddress;

  static Country? tryFromJson(Json json) {
    final name = asString(json['Name']);
    if (name == null) return null;
    return Country(name: name, automaticAddress: asBool(json['AutomaticAdress']));
  }
}

/// What `AdressValid` found for a postcode and house number.
class AddressLookup {
  const AddressLookup({required this.street, required this.city, this.zipCode});

  final String street;
  final String city;
  final String? zipCode;

  /// Null when the server found nothing (it then leaves the fields empty).
  static AddressLookup? tryFromJson(Json json) {
    final street = asString(json['Address']);
    final city = asString(json['City']);
    if (street == null || city == null) return null;
    return AddressLookup(street: street, city: city, zipCode: asString(json['Zipcode']));
  }
}

/// The languages the gym can write to you in. The server uses locale codes: `nl_NL` was
/// seen in real data; the others follow the same pattern.
const gymLanguages = ['nl_NL', 'en_GB'];
