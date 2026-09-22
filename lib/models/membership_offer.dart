import '../utils/json.dart';

/// A membership the gym offers (`MembershipDefinitions`, and `Upgrade` for switching). Only
/// shown: taking one out needs a signature and a bank account, and goes through the gym.
class MembershipOffer {
  const MembershipOffer({
    required this.id,
    required this.description,
    this.amount,
    this.promotion = false,
    this.promotionInfo,
    this.paymentMethod,
  });

  final int id;
  final String description;

  /// As the API formats it: "€ 54,50 per maand".
  final String? amount;
  final bool promotion;
  final String? promotionInfo;
  final String? paymentMethod;

  static MembershipOffer? tryFromJson(Json json) {
    final id = asInt(json['MembershipDefinitionId']);
    if (id == null) return null;
    return MembershipOffer(
      id: id,
      description: asString(json['Description']) ?? '$id',
      amount: asString(json['AmountString']),
      promotion: asBool(json['IsAction']),
      promotionInfo: asString(json['ActionInfo']),
      paymentMethod: asString(json['PaymentMethodString']),
    );
  }
}

/// A condition that comes with an offer. Seen in real data: `AVG` (privacy) and
/// `GeneralTerms` with a PDF, `OptIn` without.
class OfferCondition {
  const OfferCondition({
    required this.type,
    required this.text,
    this.linkText,
    this.hasPdf = false,
    this.mandatory = false,
  });

  /// Goes back as `ConditionType` to fetch the PDF.
  final String type;
  final String text;
  final String? linkText;
  final bool hasPdf;
  final bool mandatory;

  static OfferCondition? tryFromJson(Json json) {
    final type = asString(json['ConditionType']);
    if (type == null) return null;
    return OfferCondition(
      type: type,
      text: asString(json['Text']) ?? type,
      linkText: asString(json['LinkText']),
      hasPdf: asBool(json['HasBase64']),
      mandatory: asBool(json['Mandatory']),
    );
  }
}

class OfferConditions {
  const OfferConditions({this.conditions = const [], this.ibanRequired = false});

  final List<OfferCondition> conditions;
  final bool ibanRequired;
}

/// What starting on an offer costs (`FirstCosts`), as the API formats the amounts.
class FirstCosts {
  const FirstCosts({this.description, this.firstCosts, this.total, this.deposits = const []});

  /// "Kosten abonnement 1e periode tot 01-10-2026".
  final String? description;
  final String? firstCosts;
  final String? total;
  final List<({String description, String amount})> deposits;

  factory FirstCosts.fromJson(Json json) => FirstCosts(
    description: asString(json['FirstCostString']),
    firstCosts: asString(json['FirstCostsAmountString']),
    total: asString(json['TotalAmountString']),
    deposits: [
      for (final d in asList(json['Deposits']))
        if ((asString(d['Description']), asString(d['AmountString'])) case (
          final description?,
          final amount?,
        ))
          (description: description, amount: amount),
    ],
  );
}
