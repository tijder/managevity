import '../utils/json.dart';

/// News and notifications share the same shape.
class NewsItem {
  const NewsItem({required this.title, this.description, this.html, this.date});

  final String title;
  final String? description;
  final String? html;
  final DateTime? date;

  static NewsItem? tryFromJson(Json json) {
    final title = asString(json['Title']);
    if (title == null && asString(json['Description']) == null) return null;
    return NewsItem(
      title: title ?? '',
      description: asString(json['Description']),
      html: asString(json['HTML']),
      date: asDateTime(json['Date']),
    );
  }
}
