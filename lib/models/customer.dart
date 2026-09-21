import '../utils/json.dart';

class Customer {
  const Customer({
    required this.fullName,
    this.firstName,
    this.email,
    this.phone,
    this.phoneMobile,
    this.address,
    this.houseNumber,
    this.addition,
    this.zipCode,
    this.city,
    this.country,
    this.language,
    this.birthday,
    this.membershipExpirationWarning,
    this.balance,
    this.hasSportsCredits = false,
    this.sportsCredits,
    this.numberOfInvoices,
    this.multipleCompanies = false,
  });

  final String fullName;
  final String? firstName;
  final String? email;
  final String? phone;
  final String? phoneMobile;
  final String? address;
  final String? houseNumber;
  final String? addition;
  final String? zipCode;
  final String? city;
  final String? country;
  final String? language;
  final DateTime? birthday;
  final String? membershipExpirationWarning;
  final String? balance;
  final bool hasSportsCredits;
  final String? sportsCredits;
  final int? numberOfInvoices;
  final bool multipleCompanies;

  factory Customer.fromJson(Json json) => Customer(
    fullName:
        asString(json['FullName']) ??
        [json['FirstName'], json['MiddleName'], json['LastName']].map(asString).nonNulls.join(' '),
    firstName: asString(json['FirstName']),
    email: asString(json['Email']),
    phone: asString(json['Phone']),
    phoneMobile: asString(json['PhoneMobile']),
    address: asString(json['Address']),
    houseNumber: asString(json['HouseNumber']),
    addition: asString(json['Addition']),
    zipCode: asString(json['ZipCode']),
    city: asString(json['City']),
    country: asString(json['Country']),
    language: asString(json['Language']),
    birthday: asDateTime(json['Birthday']),
    membershipExpirationWarning: asString(json['MembershipExperationWarning']),
    balance: asString(json['Saldo']),
    hasSportsCredits: asBool(json['SportscreditsBool']),
    sportsCredits: asString(json['Sportscredits']),
    numberOfInvoices: asInt(json['NumberOfInvoices']),
    multipleCompanies: asBool(json['MultipleCompanies']),
  );
}

/// What an address change sends to the API (`UserContent/SetUserContent`).
class ContactDetails {
  const ContactDetails({
    required this.address,
    required this.houseNumber,
    required this.addition,
    required this.zipCode,
    required this.city,
    required this.phone,
    required this.phoneMobile,
  });

  final String address;
  final int? houseNumber;
  final String addition;
  final String zipCode;
  final String city;
  final String phone;
  final String phoneMobile;

  Json toJson() => {
    'Address': address,
    'HouseNumber': houseNumber,
    'Addition': addition,
    'ZipCode': zipCode,
    'City': city,
    'Phone': phone,
    'PhoneMobile': phoneMobile,
  };
}

/// The response to `UserContent`: the customer plus what the gym says about itself.
class UserContent {
  const UserContent({
    required this.customer,
    this.companyName,
    this.photoUrl,
    this.latitude,
    this.longitude,
  });

  final Customer customer;
  final String? companyName;
  final String? photoUrl;

  /// The only thing the API knows about where the gym is; there is no address field.
  final double? latitude;
  final double? longitude;

  factory UserContent.fromJson(Json json) {
    final company = asList(json['Companys']).firstOrNull;
    final lat = asDouble(company?['Latitude']);
    final lon = asDouble(company?['Longitude']);
    // 0,0 means "not filled in", not a spot in the Gulf of Guinea.
    final hasGeo = lat != null && lon != null && (lat != 0 || lon != 0);
    return UserContent(
      customer: Customer.fromJson(asMap(json['Customer']) ?? const {}),
      companyName: asString(company?['Name']),
      latitude: hasGeo ? lat : null,
      longitude: hasGeo ? lon : null,
      photoUrl: asString(asMap(json['Photo'])?['PublicThumbnailPath']),
    );
  }
}
