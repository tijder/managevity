import '../utils/json.dart';

/// An amount the credit can be topped up with (`Credits/GetCreditOptions`). Seen in real
/// data: `Amount` is the label ("€10"), `OriginalAmount` the number that goes back.
class CreditOption {
  const CreditOption({required this.label, required this.amount, this.info});

  final String label;
  final num amount;
  final String? info;

  static CreditOption? tryFromJson(Json json) {
    final amount = asDouble(json['OriginalAmount']);
    if (amount == null) return null;
    return CreditOption(
      label: asString(json['Amount']) ?? '$amount',
      amount: amount == amount.roundToDouble() ? amount.round() : amount,
      info: asString(json['Info']),
    );
  }
}
