import '../utils/json.dart';

class Invoice {
  const Invoice({
    required this.id,
    required this.number,
    this.status,
    this.date,
    this.amount,
    this.amountValue,
    this.location,
  });

  final int id;
  final String number;
  final String? status;

  /// As the API formats it: `dd-MM-yyyy`.
  final String? date;

  /// [date] as a date (`dd-MM-yyyy`, possibly followed by a time); null if the format differs.
  DateTime? get dateValue {
    final m = RegExp(r'^(\d{2})-(\d{2})-(\d{4})').firstMatch(date ?? '');
    if (m == null) return null;
    final day = int.parse(m[1]!), month = int.parse(m[2]!), year = int.parse(m[3]!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }

  /// The year from [date], to group by; null if the format differs.
  int? get year {
    final match = RegExp(r'(\d{4})').firstMatch(date ?? '');
    return match == null ? null : int.parse(match[1]!);
  }

  final String? amount;
  final double? amountValue;
  final String? location;

  static Invoice? tryFromJson(Json json) {
    final id = asInt(json['InvoiceID']);
    if (id == null) return null;
    return Invoice(
      id: id,
      number: asString(json['InvoiceNumber']) ?? '$id',
      status: asString(json['InvoiceStatus']),
      date: asString(json['InvoiceDate']),
      amount:
          asString(json['AmountAsString']) ?? asDouble(json['InvoiceAmount'])?.toStringAsFixed(2),
      amountValue: asDouble(json['InvoiceAmount']),
      location: asString(json['CompanyLocationInvoice']),
    );
  }
}
