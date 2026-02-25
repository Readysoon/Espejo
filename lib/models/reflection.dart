class Reflection {
  final String id;
  final String entryId;
  final String userId;
  final String content;
  final DateTime createdAt;

  Reflection({
    required this.id,
    required this.entryId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory Reflection.fromJson(Map<String, dynamic> json) {
    return Reflection(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entry_id': entryId,
      'user_id': userId,
      'content': content,
    };
  }
}
