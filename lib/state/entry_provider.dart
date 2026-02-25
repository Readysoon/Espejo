import 'package:flutter/foundation.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/day_context.dart';
import '../services/supabase_service.dart';
import '../services/mistral_service.dart';
import '../services/device_data_service.dart';

void _log(String msg) => debugPrint('[Espejo] $msg');

class EntryProvider extends ChangeNotifier {
  final _supabase = SupabaseService();
  final _mistral = MistralService();
  final _deviceData = DeviceDataService();

  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  DayContext _dayContext = DayContext();
  String? _currentConversationId;

  bool _isLoading = false;
  bool _isSending = false;
  bool _isCollectingData = false;
  bool _isFinalizing = false;
  String? _error;

  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isCollectingData => _isCollectingData;
  bool get isFinalizing => _isFinalizing;
  String? get error => _error;

  Future<void> loadConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _conversations = await _supabase.fetchConversations();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String conversationId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _messages = await _supabase.fetchMessages(conversationId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Startet einen neuen Tag: sammelt Gerätedaten, erstellt Gespräch,
  /// schickt erste Mistral-Nachricht
  Future<void> startNewDay() async {
    _isCollectingData = true;
    _error = null;
    _messages = [];
    notifyListeners();

    try {
      // 1. Gerätedaten sammeln
      _log('Schritt 1: Gerätedaten sammeln...');
      _dayContext = await _deviceData.collectDayContext();
      _log('Gerätedaten gesammelt: Schritte=${_dayContext.steps}, '
          'Standort=${_dayContext.location}, Wetter=${_dayContext.weather}, '
          'Kalender=${_dayContext.calendarEvents.length} Einträge');

      // 2. Gespräch in Supabase anlegen
      _log('Schritt 2: Gespräch in Supabase anlegen...');
      final conversation = await _supabase.createConversation(
        steps: _dayContext.steps,
        location: _dayContext.location,
        weather: _dayContext.weather,
      );
      _currentConversationId = conversation.id;
      _conversations.insert(0, conversation);
      _isCollectingData = false;
      _isSending = true;
      notifyListeners();
      _log('Gespräch angelegt: id=${conversation.id}');

      // 3. Mistral eröffnet das Gespräch
      _log('Schritt 3: Mistral-Eröffnung anfragen...');
      final opening = await _mistral.startDayConversation(_dayContext);
      _log('Mistral-Eröffnung erhalten: ${opening.substring(0, opening.length.clamp(0, 80))}...');

      // 4. Eröffnungsnachricht speichern
      _log('Schritt 4: Eröffnungsnachricht in Supabase speichern...');
      final assistantMsg = await _supabase.createMessage(
        conversationId: _currentConversationId!,
        role: 'assistant',
        content: opening,
      );
      _messages.add(assistantMsg);
      _log('startNewDay abgeschlossen.');
    } catch (e, stack) {
      _log('FEHLER in startNewDay: $e');
      _log('Stack: $stack');
      _error = e.toString();
      _isCollectingData = false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Sendet eine Benutzernachricht und speichert die Mistral-Antwort
  Future<void> sendMessage(String content) async {
    if (_currentConversationId == null) return;

    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      // Benutzernachricht speichern
      final userMsg = await _supabase.createMessage(
        conversationId: _currentConversationId!,
        role: 'user',
        content: content,
      );
      _messages.add(userMsg);
      notifyListeners();

      // Mistral antwortet
      final history = _messages
          .where((m) => m.id != userMsg.id)
          .map((m) => m.toChatFormat())
          .toList();

      final aiResponse = await _mistral.sendMessage(
        userMessage: content,
        history: history,
        context: _dayContext,
      );

      final assistantMsg = await _supabase.createMessage(
        conversationId: _currentConversationId!,
        role: 'assistant',
        content: aiResponse,
      );
      _messages.add(assistantMsg);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// Beim Verlassen: Mistral generiert Titel, Unterüberschrift und Zusammenfassung
  Future<void> finalizeConversation() async {
    if (_currentConversationId == null || _messages.isEmpty) {
      _currentConversationId = null;
      _dayContext = DayContext();
      return;
    }

    _isFinalizing = true;
    notifyListeners();

    try {
      final chatHistory = _messages.map((m) => m.toChatFormat()).toList();
      final summary = await _mistral.generateDiarySummary(
        chatHistory: chatHistory,
        context: _dayContext,
      );

      await _supabase.updateConversationSummary(
        conversationId: _currentConversationId!,
        title: summary['title']!,
        subtitle: summary['subtitle']!,
        summary: summary['summary']!,
      );

      // Lokalen State aktualisieren
      final idx = _conversations.indexWhere((c) => c.id == _currentConversationId);
      if (idx != -1) {
        final old = _conversations[idx];
        _conversations[idx] = Conversation(
          id: old.id,
          userId: old.userId,
          title: summary['title']!,
          subtitle: summary['subtitle'],
          summary: summary['summary'],
          date: old.date,
          steps: old.steps,
          location: old.location,
          weather: old.weather,
          createdAt: old.createdAt,
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isFinalizing = false;
      _currentConversationId = null;
      _dayContext = DayContext();
      notifyListeners();
    }
  }

  Future<void> openExistingConversation(String conversationId) async {
    _currentConversationId = conversationId;
    _dayContext = DayContext();
    await loadMessages(conversationId);
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _supabase.deleteConversation(conversationId);
      _conversations.removeWhere((c) => c.id == conversationId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearMessages() {
    _messages = [];
    _currentConversationId = null;
    _dayContext = DayContext();
    notifyListeners();
  }
}
