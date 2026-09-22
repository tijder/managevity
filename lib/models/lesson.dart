import '../utils/json.dart';

/// A single lesson. The API supplies the same lesson at three levels of detail (row in a
/// list, LessonDefinition, LessonById); everything the thin variants lack is nullable.
class Lesson {
  const Lesson({
    required this.id,
    required this.description,
    required this.startUtc,
    required this.endUtc,
    required this.bookingStatus,
    this.locationId,
    this.locationName,
    this.room,
    this.activity,
    this.group,
    this.trainer,
    this.additionalInformation,
    this.color,
    this.participants,
    this.maximumParticipants,
    this.minimumParticipants,
    this.full = false,
    this.liked = false,
    this.canUseWaitingList = false,
    this.amount,
    this.warning,
    this.thirdPartyId,
  });

  final int id;
  final String description;
  final DateTime startUtc;
  final DateTime endUtc;
  final BookingStatus bookingStatus;
  final int? locationId;
  final String? locationName;
  final String? room;
  final String? activity;
  final String? group;
  final String? trainer;
  final String? additionalInformation;
  final String? color;

  /// How many people are booked. The API calls it `SpotsInt`, but it counts the spots
  /// *taken*: across 231 lessons of a real schedule (probe, 22-09-2026) `Full` was true
  /// exactly when it equalled `MaximumParticipants`, and it was never higher.
  final int? participants;
  final int? maximumParticipants;
  final int? minimumParticipants;
  final bool full;
  final bool liked;
  final bool canUseWaitingList;

  /// What the lesson costs if it has to be bought individually, as the API formats it.
  final String? amount;
  final String? warning;
  final String? thirdPartyId;

  DateTime get start => startUtc.toLocal();
  DateTime get end => endUtc.toLocal();
  bool get isPast => endUtc.isBefore(DateTime.now().toUtc());

  /// Spots still free; null when the maximum or the count is unknown.
  int? get spotsLeft => participants == null || maximumParticipants == null
      ? null
      : (maximumParticipants! - participants!).clamp(0, maximumParticipants!);

  /// Full according to the server, or by the numbers.
  bool get isFull => full || spotsLeft == 0;

  /// Null if the JSON is not a usable lesson (no id or no times).
  static Lesson? tryFromJson(Json json) {
    final id = asInt(json['LessonId']) ?? asInt(json['_id']);
    final start = asDateTime(json['UTCStartTime'], assumeUtc: true);
    final end = asDateTime(json['UTCEndTime'], assumeUtc: true);
    if (id == null || start == null || end == null) return null;
    return Lesson(
      id: id,
      description: asString(json['Description']) ?? asString(json['Activity']) ?? '',
      startUtc: start,
      endUtc: end,
      bookingStatus: BookingStatus(asString(json['BookingStatus']) ?? ''),
      locationId: asInt(json['LocationID']) ?? asInt(json['LocationId']),
      locationName: asString(json['LocationName']),
      room: asString(json['Location']),
      activity: asString(json['Activity']),
      group: asString(json['Group']),
      trainer: asString(json['Trainer']),
      additionalInformation: asString(json['AdditionalInformation']) ?? asString(json['ExtraInfo']),
      color: asString(json['LessonColor']),
      participants: asInt(json['SpotsInt']),
      maximumParticipants: asInt(json['MaximumParticipants']),
      minimumParticipants: asInt(json['MinimumParticipants']),
      full: asBool(json['Full']),
      liked: asBool(json['LikedLesson']),
      canUseWaitingList: asBool(json['CanUseWaitingList']),
      amount: asString(json['AmountAsString']) ?? asString(json['AmountString']),
      warning: json['Warning'] is String ? asString(json['Warning']) : null,
      thirdPartyId: asString(json['ThirdPartyId']),
    );
  }

  Json toJson() => {
    'LessonId': id,
    'Description': description,
    'UTCStartTime': startUtc.toUtc().toIso8601String(),
    'UTCEndTime': endUtc.toUtc().toIso8601String(),
    'BookingStatus': bookingStatus.raw.isEmpty ? null : bookingStatus.raw,
    'LocationID': locationId,
    'LocationName': locationName,
    'Location': room,
    'Activity': activity,
    'Group': group,
    'Trainer': trainer,
    'AdditionalInformation': additionalInformation,
    'LessonColor': color,
    'SpotsInt': participants,
    'MaximumParticipants': maximumParticipants,
    'MinimumParticipants': minimumParticipants,
    'Full': full,
    'LikedLesson': liked,
    'CanUseWaitingList': canUseWaitingList,
    'AmountAsString': amount,
    'Warning': warning,
    'ThirdPartyId': thirdPartyId,
  };

  Lesson copyWith({BookingStatus? bookingStatus, bool? liked, int? participants}) => Lesson(
    id: id,
    description: description,
    startUtc: startUtc,
    endUtc: endUtc,
    bookingStatus: bookingStatus ?? this.bookingStatus,
    locationId: locationId,
    locationName: locationName,
    room: room,
    activity: activity,
    group: group,
    trainer: trainer,
    additionalInformation: additionalInformation,
    color: color,
    participants: participants ?? this.participants,
    maximumParticipants: maximumParticipants,
    minimumParticipants: minimumParticipants,
    full: full,
    liked: liked ?? this.liked,
    canUseWaitingList: canUseWaitingList,
    amount: amount,
    warning: warning,
    thirdPartyId: thirdPartyId,
  );
}

/// The API gives the status as free text and the spec does not list the values. The raw
/// value is therefore kept; the derivations below are the only place that interprets it.
///
/// TODO(probe): record the real values with tool/probe.dart and make this exact.
///
/// Deliberately wrapped around a non-nullable String: at runtime an extension type *is* its
/// representation, so `BookingStatus(null)` would simply be `null` and drop out of a `??`.
extension type const BookingStatus(String raw) {
  String get _norm => raw.toLowerCase();

  bool get isWaitingList => _norm.contains('wait') || _norm.contains('wacht');

  bool get isBooked =>
      !isWaitingList &&
      !_norm.contains('not') &&
      !_norm.contains('niet') &&
      (_norm.contains('book') ||
          _norm.contains('geboekt') ||
          _norm.contains('reserv') ||
          _norm.contains('joined'));

  /// Booked or on the waiting list: everything for which cancelling makes sense.
  bool get isMine => isBooked || isWaitingList;
}
