import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'remote_config_service.dart';

class AiService {
  String? _cachedApiKey;

  Future<String> _getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }
    
    // 1. Try Firestore first (allows easy dynamic setup)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('groq')
          .get();
      if (doc.exists && doc.data() != null) {
        final key = doc.data()?['apiKey'] as String?;
        if (key != null && key.trim().isNotEmpty) {
          _cachedApiKey = key.trim();
          debugPrint('🔑 Loaded Groq API Key from Firestore admin_settings/groq');
          return _cachedApiKey!;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading Groq key from Firestore: $e');
    }

    // 2. Try Remote Config fallback
    try {
      final rcKey = remoteConfigService.groqApiKey;
      if (rcKey.isNotEmpty) {
        _cachedApiKey = rcKey;
        return rcKey;
      }
    } catch (e) {
      debugPrint('⚠️ Error loading Remote Config key: $e');
    }

    return '';
  }

  // Groq's lightning fast Llama 3 model
  static const String _model = 'llama-3.1-8b-instant';

  static const String _systemPrompt =
      'You are the "Home237 Virtual Demarcheur", a highly intelligent, polite, '
      'and professional real estate assistant for Cameroon. '
      'You speak both English and French fluently — always reply in the same language the user writes in. '
      'Keep your answers concise and format them beautifully with emojis where appropriate. '
      'You have expert knowledge of ALL neighborhoods in Cameroon. For example: '
      'Douala (Akwa, Bonanjo, Bonapriso, Bonamoussadi, Makepe, Deido, Logpom, Ndogbong, Kotto, etc.), '
      'Yaoundé (Bastos, Biyem-Assi, Nlonkak, Essos, Mvan, Obili, Ngoa-Ekelle, Odza, etc.), '
      'Buea (Molyko, Bomaka, Muea, Bokwango, Clerks Quarters, Ndongo, Great Soppo, etc.), '
      'Bamenda (Nkwen, Up-Station, Bambili, Mankon, Ntarinkon, Commercial Avenue), '
      'and Limbe (Mile 4, Half Mile, Down Beach, Bota, Isokolo). '
      'IMPORTANT RULE FOR SPECIFIC AREA REQUESTS: If a user says they want a house in a particular area/neighborhood (e.g. Ndogbong, Bastos, Molyko, etc.), '
      'you MUST call the get_real_time_properties tool to fetch current listings. If the tool returns no properties matching that area, '
      'you MUST tell the user: "There is no house listed in this area right now" (or "Il n\'y a pas de maison disponible dans ce quartier pour le moment" in French). '
      'IMPORTANT RULE FOR GENERAL AVAILABILITY QUERY: If the user asks "are the houses available in your app now?", '
      '"maisons libres", vacant houses, or similar general availability queries, you MUST call the get_real_time_properties tool. '
      'If yes (properties exist), you MUST answer yes and immediately tell the user the region and location of those houses at once in your response '
      '(e.g., "Yes! We have available houses located in Douala - Makepe, Buea - Molyko, etc."). '
      'IMPORTANT CHAT ACTIONS: If they reply positively to seeing them (e.g. "yes", "oui", "show me", "montre-moi"), you MUST call the search_properties tool to open the search results. '
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
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      if (_history.isNotEmpty && _history.last['role'] == 'user') {
        _history.removeLast();
      }
      return 'Hello! I am your Home237 AI Virtual Assistant. 🤖\n\n'
             '⚠️ **API Key is not configured.**\n'
             'To enable chat support, the Admin must configure the Groq API key in Firestore:\n'
             '1. Go to your Firebase Console → Firestore Database.\n'
             '2. Under `admin_settings` collection, create a document named `groq`.\n'
             '3. Add a field named `apiKey` with your Groq API key (starts with `gsk_`).\n\n'
             'You can get a free, high-speed API key at [console.groq.com](https://console.groq.com).';
    }

    try {
      final url = 'https://api.groq.com/openai/v1/chat/completions';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
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
                      'city': data['city'] ?? '',
                      'neighborhood': data['neighborhood'] ?? '',
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
