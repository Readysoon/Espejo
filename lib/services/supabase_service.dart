import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  // --- Auth ---

  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  String? get currentUserId => _client.auth.currentUser?.id;

  // --- Conversations ---

  Future<List<Conversation>> fetchConversations() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final data = await _client
        .from('conversations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => Conversation.fromJson(e)).toList();
  }

  Future<Conversation> createConversation({
    String title = 'Neues Gespräch',
    int? steps,
    String? location,
    String? weather,
  }) async {
    final userId = currentUserId!;

    final data = await _client
        .from('conversations')
        .insert({
          'user_id': userId,
          'title': title,
          'steps': steps,
          'location': location,
          'weather': weather,
        })
        .select()
        .single();

    return Conversation.fromJson(data);
  }

  Future<void> updateConversationSummary({
    required String conversationId,
    required String title,
    required String subtitle,
    required String summary,
  }) async {
    await _client.from('conversations').update({
      'title': title,
      'subtitle': subtitle,
      'summary': summary,
    }).eq('id', conversationId);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _client.from('conversations').delete().eq('id', conversationId);
  }

  // --- Messages ---

  Future<List<Message>> fetchMessages(String conversationId) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (data as List).map((m) => Message.fromJson(m)).toList();
  }

  Future<Message> createMessage({
    required String conversationId,
    required String role,
    required String content,
  }) async {
    final data = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'role': role,
          'content': content,
        })
        .select()
        .single();

    return Message.fromJson(data);
  }
}
