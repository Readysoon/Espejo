import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/entry.dart';
import '../models/reflection.dart';

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

  // --- Entries ---

  Future<List<Entry>> fetchEntries() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final data = await _client
        .from('entries')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => Entry.fromJson(e)).toList();
  }

  Future<Entry> createEntry(String content) async {
    final userId = currentUserId!;
    final data = await _client
        .from('entries')
        .insert({'user_id': userId, 'content': content})
        .select()
        .single();

    return Entry.fromJson(data);
  }

  Future<void> deleteEntry(String entryId) async {
    await _client.from('entries').delete().eq('id', entryId);
  }

  // --- Reflections ---

  Future<List<Reflection>> fetchReflections(String entryId) async {
    final data = await _client
        .from('reflections')
        .select()
        .eq('entry_id', entryId)
        .order('created_at', ascending: true);

    return (data as List).map((r) => Reflection.fromJson(r)).toList();
  }

  Future<Reflection> createReflection(String entryId, String content) async {
    final userId = currentUserId!;
    final data = await _client
        .from('reflections')
        .insert({
          'entry_id': entryId,
          'user_id': userId,
          'content': content,
        })
        .select()
        .single();

    return Reflection.fromJson(data);
  }
}
