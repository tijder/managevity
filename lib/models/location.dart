import '../utils/json.dart';

class Location {
  const Location({required this.id, required this.name});

  final int id;
  final String name;

  static Location? tryFromJson(Json json) {
    final id = asInt(json['LocationId']);
    if (id == null) return null;
    return Location(id: id, name: asString(json['NameLocation']) ?? '$id');
  }

  Json toJson() => {'LocationId': id, 'NameLocation': name};
}
