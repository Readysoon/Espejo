class Conversation {
  final String id;
  final String userId;
  final String title;
  final String? subtitle;
  final String? summary;
  final DateTime date;
  final int? steps;
  final String? location;
  final String? weather;
  final DateTime createdAt;

  Conversation({
    required this.id,
    required this.userId,
    required this.title,
    this.subtitle,
    this.summary,
    required this.date,
    this.steps,
    this.location,
    this.weather,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      summary: json['summary'] as String?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      steps: json['steps'] as int?,
      location: json['location'] as String?,
      weather: json['weather'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
