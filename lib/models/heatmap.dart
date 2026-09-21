import '../utils/json.dart';

/// How busy it is during one hour of a day (`Heatmap/PerDay`) or one **part of the day** of
/// a weekday (`Heatmap`). In the week overview `sorttod` is not an hour but a part of the
/// day: the real API supplies three per day (morning, afternoon, evening), not 24.
class HeatmapCell {
  const HeatmapCell({required this.hour, required this.value, this.day});

  /// Weekday as the API numbers it (`sortday`); null in the day view.
  final int? day;

  /// The hour (day view) or the sequence number of the part of the day (week view).
  final int hour;
  final double value;

  static HeatmapCell? tryFromJson(Json json) {
    final hour = asInt(json['sorttod']) ?? asInt(json['hour']);
    final value = asDouble(json['number']);
    if (hour == null || value == null) return null;
    return HeatmapCell(day: asInt(json['sortday']), hour: hour, value: value);
  }
}
