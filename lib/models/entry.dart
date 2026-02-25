class Entry {
  final String id;
  final String userId;
  final String content;
  final DateTime createdAt;

  Entry({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'content': content,
    };
  }
}
