/// The API is a Mendix export: numbers sometimes arrive as strings, dates sometimes without
/// a zone, and missing fields are normal. These helpers never throw on an unexpected shape.
typedef Json = Map<String, dynamic>;

int? asInt(Object? v) => switch (v) {
  int i => i,
  double d => d.toInt(),
  String s => int.tryParse(s.trim()),
  _ => null,
};

double? asDouble(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s.trim().replaceAll(',', '.')),
  _ => null,
};

bool asBool(Object? v, {bool fallback = false}) => switch (v) {
  bool b => b,
  String s => s.toLowerCase() == 'true',
  _ => fallback,
};

/// Empty strings count as absent.
String? asString(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Fields named `UTC…` arrive without a zone designator but *are* UTC; set [assumeUtc].
DateTime? asDateTime(Object? v, {bool assumeUtc = false}) {
  final s = asString(v);
  if (s == null) return null;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  if (parsed.isUtc || !assumeUtc) return parsed;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
  );
}

List<Json> asList(Object? v) => [
  if (v is List)
    for (final item in v)
      if (item is Map) item.cast<String, dynamic>(),
];

Json? asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : null;
