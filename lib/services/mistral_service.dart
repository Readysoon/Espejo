import 'dart:convert';
import 'package:http/http.dart' as http;

class MistralService {
  static const String _apiKey = String.fromEnvironment('MISTRAL_API_KEY');
  static const String _baseUrl = 'https://api.mistral.ai/v1';
  static const String _model = 'mistral-large-latest';

  Future<String> chat(List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Mistral API Fehler: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['choices'][0]['message']['content'] as String;
  }

  Future<String> sendMessage({
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    final messages = [
      ...history,
      {'role': 'user', 'content': userMessage},
    ];
    return chat(messages);
  }
}
