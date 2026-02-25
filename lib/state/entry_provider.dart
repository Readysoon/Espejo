import 'package:flutter/foundation.dart';
import '../models/entry.dart';
import '../models/reflection.dart';
import '../services/supabase_service.dart';
import '../services/mistral_service.dart';

class EntryProvider extends ChangeNotifier {
  final _supabase = SupabaseService();
  final _mistral = MistralService();

  List<Entry> _entries = [];
  List<Reflection> _reflections = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  List<Entry> get entries => _entries;
  List<Reflection> get reflections => _reflections;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;

  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _entries = await _supabase.fetchEntries();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReflections(String entryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reflections = await _supabase.fetchReflections(entryId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sendet eine Nachricht: speichert Entry in Supabase, fragt Mistral,
  /// speichert die Antwort als Reflection.
  Future<void> sendMessage(String content) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Benutzernachricht in Supabase speichern
      final entry = await _supabase.createEntry(content);
      _entries.insert(0, entry);
      notifyListeners();

      // 2. Chat-Verlauf aufbauen (letzte 10 Nachrichten als Kontext)
      final history = _buildHistory(entry.id);

      // 3. Mistral anfragen
      final aiResponse = await _mistral.sendMessage(
        userMessage: content,
        history: history,
      );

      // 4. KI-Antwort als Reflection in Supabase speichern
      final reflection = await _supabase.createReflection(entry.id, aiResponse);
      _reflections.add(reflection);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String entryId) async {
    try {
      await _supabase.deleteEntry(entryId);
      _entries.removeWhere((e) => e.id == entryId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearReflections() {
    _reflections = [];
    notifyListeners();
  }

  List<Map<String, String>> _buildHistory(String currentEntryId) {
    return _reflections.map((r) => {
      'role': 'assistant',
      'content': r.content,
    }).toList();
  }
}
