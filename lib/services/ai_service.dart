import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'remote_config_service.dart';

class AiService {
  // Key is fetched at runtime from Firebase Remote Config — never stored in code.
  String get _apiKey => remoteConfigService.groqApiKey;

  // Groq's lightning fast Llama 3 model
  static const String _model = 'llama-3.1-8b-instant';

  static const String _systemPrompt =
      'You are the "Home237 Virtual Demarcheur", a highly intelligent, polite, '
      'and professional real estate assistant for Cameroon. '
      'You have expert knowledge of ALL neighborhoods in Cameroon. For example: '
      'Douala (Akwa, Bonanjo, Bonapriso, Bonamoussadi, Makepe, Deido, Logpom, Ndogbong, Kotto, etc.), '
      'Yaoundé (Bastos, Biyem-Assi, Nlonkak, Essos, Mvan, Obili, Ngoa-Ekelle, Odza, etc.), '
      'Buea (Molyko, Bomaka, Muea, Bokwango, Clerks Quarters, Ndongo, Great Soppo, etc.), '
      'Bamenda (Nkwen, Up-Station, Bambili, Mankon, Ntarinkon, Commercial Avenue), '
      'and Limbe (Mile 4, Half Mile, Down Beach, Bota, Isokolo). '
      'IMPORTANT RULE: If a user asks for houses in a specific city (like Buea), YOU MUST '
      'reply by explicitly listing the specific neighborhoods in that city where they can find '
      'houses on the app (e.g. "We have properties in Molyko, Bomaka, Muea..."). '
      'IMPORTANT AVAILABLE HOUSES / MAISONS LIBRES RULE: If the user asks if there are available houses, '
      '"maisons libres", vacant houses, or free houses in the app, you MUST first call the get_real_time_properties '
      'tool to verify if there are indeed houses available in the database. If properties are returned, you MUST NOT list '
      'them or show details immediately. Instead, you MUST politely inform the user that available houses exist, and '
      'explicitly ask them if they would love to see them (e.g., "Yes! We have available houses on Home237. Would you love '
      'to see them?" or "Oui ! Nous avons des maisons libres sur Home237. Aimeriez-vous les voir ?"). '
      'If they reply positively (e.g., "yes", "oui", "I would love to", "je veux bien", "show me", "montre-moi"), you MUST '
      'call the search_properties tool to instantly open the search results for them. '
      'You speak both English and French fluently — always reply in the same language the user writes in. '
      'Keep your answers concise and format them beautifully with emojis where appropriate. '
      'When asked about viewing fees (frais de visite) or scams, strongly explain that Home237 uses '
      'a "Smart Escrow" system powered by Fapshi where the fee is held securely and only released '
      'when the tenant physically scans the agent\'s QR code at the property. '
      'When asked about real-time specific property prices or listings, USE the get_real_time_properties tool to fetch accurate live data from the database, do not make up fake prices!';

  // Conversation history for multi-turn chat
  final List<Map<String, dynamic>> _history = [];

  AiService() {
    // Seed the conversation with the system prompt
    _history.add({
      'role': 'system',
      'content': _systemPrompt
    });
  }

  Future<String> sendMessage(String userMessage) async {
    // Add user message to history
    _history.add({
      'role': 'user',
      'content': userMessage
    });

    return _processGroqRequest();
  }

  Future<String> _processGroqRequest() async {

    try {
      final url = 'https://api.groq.com/openai/v1/chat/completions';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': _history,
          'temperature': 0.75,
          'max_tokens': 800,
          'tools': [
            {
              "type": "function",
              "function": {
                "name": "open_tour_scheduler",
                "description": "Call this ONLY when the user explicitly asks to schedule a tour or view a property. It will instantly open the tour booking screen for them.",
                "parameters": {
                  "type": "object",
                  "properties": {
                     "reason": {
                       "type": "string",
                       "description": "A short sentence explaining why you are opening the tour scheduler."
                     }
                  },
                  "required": ["reason"]
                }
              }
            },
            {
              "type": "function",
              "function": {
                "name": "search_properties",
                "description": "Call this when the user asks to see properties, houses, or apartments matching certain characteristics (e.g. 2 bedrooms in Buea). It will instantly open the search screen pre-filled with their requirements.",
                "parameters": {
                  "type": "object",
                  "properties": {
                     "query": {
                       "type": "string",
                       "description": "The search query to filter properties (e.g. '2 bedroom Molyko')."
                     }
                  },
                  "required": ["query"]
                }
              }
            },
            {
              "type": "function",
              "function": {
                "name": "get_real_time_properties",
                "description": "Call this to get real-time information on property prices and listings from the database. Use this when the user asks for current prices or available properties.",
                "parameters": {
                  "type": "object",
                  "properties": {
                     "limit": {
                       "type": "integer",
                       "description": "The number of properties to fetch (default 5)."
                     }
                  }
                }
              }
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['choices']?[0]?['message'];
        
        if (message != null) {
          // Check for tool calls first!
          if (message['tool_calls'] != null && (message['tool_calls'] as List).isNotEmpty) {
             final toolCall = message['tool_calls'][0];
             
             if (toolCall['function']['name'] == 'open_tour_scheduler') {
                // Add the tool call to history so AI knows it executed successfully
                _history.add(message);
                _history.add({
                  'role': 'tool',
                  'tool_call_id': toolCall['id'],
                  'name': toolCall['function']['name'],
                  'content': '{"success": true}'
                });
                return "[ACTION: OPEN_TOUR_REQUESTS]";
             } else if (toolCall['function']['name'] == 'search_properties') {
                // Add the tool call to history so AI knows it executed successfully
                _history.add(message);
                _history.add({
                  'role': 'tool',
                  'tool_call_id': toolCall['id'],
                  'name': toolCall['function']['name'],
                  'content': '{"success": true}'
                });
                final args = jsonDecode(toolCall['function']['arguments']);
                return "[ACTION: SEARCH_PROPERTIES: ${args['query']}]";
             } else if (toolCall['function']['name'] == 'get_real_time_properties') {
                // Fetch properties from Firestore
                final args = toolCall['function']['arguments'] != null ? jsonDecode(toolCall['function']['arguments']) : {};
                final int limit = args['limit'] ?? 5;
                final snapshot = await FirebaseFirestore.instance.collection('properties').limit(limit).get();
                
                List<Map<String, dynamic>> properties = [];
                for (var doc in snapshot.docs) {
                  final data = doc.data();
                  final status = data['status'] ?? '';
                  // Only include if approved or active
                  if (status == 'approved' || status == 'active') {
                    properties.add({
                      'title': data['title'] ?? 'Unknown Property',
                      'price': data['price'] ?? '0 FCFA',
                      'location': data['location'] ?? 'Unknown',
                      'bedrooms': data['beds'] ?? '0',
                      'type': data['type'] ?? 'Unknown',
                      'status': status,
                    });
                  }
                }
                
                // Add the tool call and its result to history
                _history.add(message);
                _history.add({
                  'role': 'tool',
                  'tool_call_id': toolCall['id'],
                  'name': toolCall['function']['name'],
                  'content': jsonEncode({"success": true, "properties": properties})
                });
                
                // Recursively call to let AI generate a response based on the fetched data
                return _processGroqRequest();
             }
          }

          final text = message['content'] as String?;
          if (text != null && text.isNotEmpty) {
            // Success! Add AI response to history
            _history.add({
              'role': 'assistant',
              'content': text
            });
            return text;
          }
        }
        return '';
      } else {
        String errorMessage = 'Unknown error';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error']?['message'] ?? response.body;
        } catch (_) {
          errorMessage = response.body;
        }
        
        debugPrint('Groq API Error: $errorMessage');
        _history.removeLast();
        return "DEBUG API Error: $errorMessage";
      }
    } catch (e) {
      debugPrint('AI Network Error: $e');
      _history.removeLast();
      return "DEBUG Network: $e";
    }
  }

  /// Resets the conversation
  void resetChat() {
    _history.clear();
    _history.add({
      'role': 'system',
      'content': _systemPrompt
    });
  }

  /// Injects a past message into history (used to rebuild context from Firestore)
  void injectHistory(String role, String content) {
    _history.add({
      'role': role,
      'content': content,
    });
  }
}

// Global singleton
final aiService = AiService();
