import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/day_context.dart';

class MistralService {
  static const String _apiKey = String.fromEnvironment('MISTRAL_API_KEY');
  static const String _baseUrl = 'https://api.mistral.ai/v1';
  static const String _model = 'mistral-large-latest';

  Future<String> _complete(List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({'model': _model, 'messages': messages}),
    );

    if (response.statusCode != 200) {
      throw Exception('Mistral API Fehler: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['choices'][0]['message']['content'] as String;
  }

  /// Eröffnungsnachricht von Mistral mit Tagesdaten als Kontext
  Future<String> startDayConversation(DayContext context) async {
    final systemPrompt = _buildSystemPrompt(context);
    return _complete([
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'user',
        'content': 'Starte das Gespräch.',
      },
    ]);
  }

  /// Sendet eine Benutzernachricht im laufenden Gespräch
  Future<String> sendMessage({
    required String userMessage,
    required List<Map<String, String>> history,
    required DayContext context,
  }) async {
    final systemPrompt = _buildSystemPrompt(context);
    return _complete([
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': userMessage},
    ]);
  }

  /// Generiert Titel, Unterüberschrift und Zusammenfassung aus dem Chat-Verlauf
  Future<Map<String, String>> generateDiarySummary({
    required List<Map<String, String>> chatHistory,
    required DayContext context,
  }) async {
    final historyText = chatHistory
        .map((m) => '${m['role'] == 'user' ? 'User' : 'Espejo'}: ${m['content']}')
        .join('\n\n');

    final prompt = '''
Du hast gerade ein Gespräch mit einem Benutzer über seinen Tag geführt. 
Erstelle daraus einen strukturierten Tagebucheintrag.

${context.isEmpty ? '' : context.toPromptString()}

Gesprächsverlauf:
$historyText

Antworte NUR mit validem JSON in exakt diesem Format:
{
  "title": "Kurzer prägnanter Titel des Tages (max 6 Wörter)",
  "subtitle": "Eine Satz Unterüberschrift die den Tag zusammenfasst",
  "summary": "Eine kurze Zusammenfassung des Tages in 3-5 Sätzen, in der dritten Person oder als Tagebucheintrag formuliert"
}
''';

    final response = await _complete([
      {'role': 'user', 'content': prompt},
    ]);

    try {
      // JSON aus der Antwort extrahieren
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) throw Exception('Kein JSON gefunden');
      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      return {
        'title': json['title'] as String? ?? 'Tagebucheintrag',
        'subtitle': json['subtitle'] as String? ?? '',
        'summary': json['summary'] as String? ?? '',
      };
    } catch (_) {
      return {
        'title': 'Tagebucheintrag',
        'subtitle': '',
        'summary': response,
      };
    }
  }

  String _buildSystemPrompt(DayContext context) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Du bist Espejo, ein einfühlsamer und neugieriger Tagebuch-Assistent. '
      'Deine Aufgabe ist es, den Benutzer durch ein kurzes Gespräch dabei zu helfen, '
      'seinen Tag zu reflektieren. Stelle offene, persönliche Fragen. '
      'Sei warmherzig, interessiert und kurz in deinen Antworten (max 3 Sätze). '
      'Sprich den Benutzer direkt auf Deutsch an.',
    );

    if (!context.isEmpty) {
      buffer.writeln('\n${context.toPromptString()}');
      buffer.writeln(
        'Nutze diese Daten um das Gespräch zu personalisieren, '
        'aber frage nicht explizit danach – fließe sie natürlich ein.',
      );
    }

    return buffer.toString();
  }
}
