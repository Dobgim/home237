import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/ai_service.dart';
import 'tour_requests_screen.dart';
import 'explore_screen.dart';
import 'auth_service.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});
  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _languageChosen = false;
  String _chosenLanguage = '';
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  bool _isLoading = true;

  String? _resolvedId;
  String? _activeSessionId;
  List<QueryDocumentSnapshot> _sessions = [];

  CollectionReference get _messagesRef => FirebaseFirestore.instance
      .collection('ai_chats')
      .doc(_activeSessionId)
      .collection('messages');

  DocumentReference get _metaRef =>
      FirebaseFirestore.instance.collection('ai_chats').doc(_activeSessionId);

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _migrateGuestChatIfAny() async {
    final loggedInUid = authService.userId;
    if (loggedInUid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final guestId = prefs.getString('ai_guest_id');
      if (guestId == null) return;

      // Query all sessions belonging to the guest
      final query = await FirebaseFirestore.instance
          .collection('ai_chats')
          .where('userId', isEqualTo: guestId)
          .get();

      if (query.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in query.docs) {
          batch.update(doc.reference, {'userId': loggedInUid});
        }
        await batch.commit();
        debugPrint('🎉 Migrated ${query.docs.length} chat sessions to logged-in user.');
      }

      await prefs.remove('ai_guest_id');
    } catch (e) {
      debugPrint('Error migrating guest chat: $e');
    }
  }

  Future<void> _initChatId() async {
    if (authService.userId != null) {
      _resolvedId = authService.userId;
    } else {
      final prefs = await SharedPreferences.getInstance();
      String? guestId = prefs.getString('ai_guest_id');
      if (guestId == null) {
        guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('ai_guest_id', guestId);
      }
      _resolvedId = guestId;
    }
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);
    await _migrateGuestChatIfAny();
    await _initChatId();

    try {
      final sessionDocs = await FirebaseFirestore.instance
          .collection('ai_chats')
          .where('userId', isEqualTo: _resolvedId)
          .orderBy('updatedAt', descending: true)
          .get();

      _sessions = sessionDocs.docs;

      if (_sessions.isNotEmpty) {
        await _loadSession(_sessions.first.id);
      } else {
        await _startNewSession(shouldReloadList: false);
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      _initFreshChat();
    }
  }

  Future<void> _loadSession(String sessionId) async {
    setState(() {
      _isLoading = true;
      _activeSessionId = sessionId;
    });

    try {
      final sessionDoc = await FirebaseFirestore.instance
          .collection('ai_chats')
          .doc(sessionId)
          .get();

      if (sessionDoc.exists) {
        final data = sessionDoc.data()!;
        _chosenLanguage = data['language'] ?? '';
        _languageChosen = _chosenLanguage.isNotEmpty;

        final msgSnapshot = await FirebaseFirestore.instance
            .collection('ai_chats')
            .doc(sessionId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .get();

        _messages = msgSnapshot.docs.map((doc) {
          final d = doc.data();
          return {
            'message': d['message'] ?? '',
            'isMe': d['isMe'] ?? false,
            'time': (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            if (d['isLanguagePrompt'] == true) 'isLanguagePrompt': true,
          };
        }).toList();

        aiService.resetChat();
        if (_languageChosen) {
          final langInstruction = _chosenLanguage == 'english'
              ? 'The user has chosen ENGLISH. Respond ONLY in English.'
              : "L'utilisateur a choisi le FRANÇAIS. Réponds UNIQUEMENT en français.";
          aiService.injectHistory('user', langInstruction);
          aiService.injectHistory('assistant', 'OK');
        }
        for (final msg in _messages) {
          if (msg['isLanguagePrompt'] == true) continue;
          aiService.injectHistory(
              msg['isMe'] == true ? 'user' : 'assistant', msg['message']);
        }
      }
    } catch (e) {
      debugPrint('Error loading session $sessionId: $e');
    }

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _startNewSession({bool shouldReloadList = true}) async {
    setState(() => _isLoading = true);

    try {
      final docRef = await FirebaseFirestore.instance.collection('ai_chats').add({
        'userId': _resolvedId,
        'title': _chosenLanguage == 'french' ? 'Nouvelle conversation' : 'New Conversation',
        'language': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _activeSessionId = docRef.id;
      _languageChosen = false;
      _chosenLanguage = '';

      final greeting =
          '👋 Hello! I am your Home237 AI Virtual Assistant.\n\n'
          'Bonjour ! Je suis votre assistant virtuel Home237.\n\n'
          '🌍 Which language would you like us to chat in?\n'
          'Dans quelle langue souhaitez-vous discuter ?';

      _messages = [
        {
          'message': greeting,
          'isMe': false,
          'time': DateTime.now(),
          'isLanguagePrompt': true,
        }
      ];

      await FirebaseFirestore.instance
          .collection('ai_chats')
          .doc(_activeSessionId)
          .collection('messages')
          .add({
        'message': greeting,
        'isMe': false,
        'timestamp': FieldValue.serverTimestamp(),
        'isLanguagePrompt': true,
      });

      aiService.resetChat();

      if (shouldReloadList) {
        final sessionDocs = await FirebaseFirestore.instance
            .collection('ai_chats')
            .where('userId', isEqualTo: _resolvedId)
            .orderBy('updatedAt', descending: true)
            .get();
        _sessions = sessionDocs.docs;
      }
    } catch (e) {
      debugPrint('Error starting new session: $e');
    }

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  Future<void> _deleteSession(String sessionId) async {
    setState(() => _isLoading = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('ai_chats').doc(sessionId);
      final messages = await docRef.collection('messages').get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(docRef);
      await batch.commit();

      final sessionDocs = await FirebaseFirestore.instance
          .collection('ai_chats')
          .where('userId', isEqualTo: _resolvedId)
          .orderBy('updatedAt', descending: true)
          .get();
      _sessions = sessionDocs.docs;

      if (_activeSessionId == sessionId) {
        if (_sessions.isNotEmpty) {
          await _loadSession(_sessions.first.id);
        } else {
          await _startNewSession(shouldReloadList: false);
        }
      } else {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error deleting session $sessionId: $e');
    }
    setState(() => _isLoading = false);
  }

  void _initFreshChat() {
    aiService.resetChat();
    final greeting =
        '👋 Hello! I am your Home237 AI Virtual Assistant.\n\n'
        'Bonjour ! Je suis votre assistant virtuel Home237.\n\n'
        '🌍 Which language would you like us to chat in?\n'
        'Dans quelle langue souhaitez-vous discuter ?';

    _messages = [
      {
        'message': greeting,
        'isMe': false,
        'time': DateTime.now(),
        'isLanguagePrompt': true,
      }
    ];
    setState(() => _isLoading = false);
  }

  Future<void> _saveMessage(String message, bool isMe,
      {bool isLanguagePrompt = false}) async {
    if (_activeSessionId == null) return;
    try {
      final docRef = FirebaseFirestore.instance.collection('ai_chats').doc(_activeSessionId);
      await docRef.collection('messages').add({
        'message': message,
        'isMe': isMe,
        'timestamp': FieldValue.serverTimestamp(),
        if (isLanguagePrompt) 'isLanguagePrompt': true,
      });

      await docRef.update({
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (isMe && !isLanguagePrompt && _messages.length <= 4) {
        final userMsgs = _messages.where((m) => m['isMe'] == true && !m['message'].toString().contains('🇬🇧') && !m['message'].toString().contains('🇫🇷')).toList();
        if (userMsgs.isNotEmpty && userMsgs.length == 1) {
          final firstMsg = userMsgs.first['message'] as String;
          final words = firstMsg.split(' ');
          final title = words.length > 4 ? '${words.sublist(0, 4).join(' ')}...' : firstMsg;
          await docRef.update({'title': title});
        }
      }
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  Future<void> _saveLanguageChoice(String language) async {
    if (_activeSessionId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('ai_chats')
          .doc(_activeSessionId)
          .update({'language': language});
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  void _selectLanguage(String language) async {
    final isEnglish = language == 'english';
    final choiceText = isEnglish ? '🇬🇧 English' : '🇫🇷 Français';

    setState(() {
      _languageChosen = true;
      _chosenLanguage = language;
      _messages.add({'message': choiceText, 'isMe': true, 'time': DateTime.now()});
      _isTyping = true;
    });
    _scrollToBottom();
    _saveMessage(choiceText, true);
    _saveLanguageChoice(language);

    final langInstruction = isEnglish
        ? 'The user has chosen ENGLISH. From now on, respond ONLY in English.'
        : "L'utilisateur a choisi le FRANÇAIS. À partir de maintenant, réponds UNIQUEMENT en français.";

    final response = await aiService.sendMessage(langInstruction);
    if (!mounted) return;

    final fallback = isEnglish
        ? 'Great choice! 🎉 I\'m ready to help you find the perfect home in Cameroon.\n\nI can:\n🏠 Show you available properties\n📅 Schedule property tours\n💰 Give you real-time prices\n🔍 Search by neighborhood, budget, or features\n\nWhat are you looking for today?'
        : 'Excellent choix ! 🎉 Je suis prêt à vous aider à trouver la maison parfaite au Cameroun.\n\nJe peux :\n🏠 Vous montrer les propriétés disponibles\n📅 Planifier des visites\n💰 Vous donner les prix en temps réel\n🔍 Rechercher par quartier, budget ou caractéristiques\n\nQue recherchez-vous aujourd\'hui ?';

    final aiMsg = response.isNotEmpty ? response : fallback;
    setState(() {
      _isTyping = false;
      _messages.add({'message': aiMsg, 'isMe': false, 'time': DateTime.now()});
    });
    _scrollToBottom();
    _saveMessage(aiMsg, false);
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final userMessage = _messageController.text.trim();

    setState(() {
      _messages.add({'message': userMessage, 'isMe': true, 'time': DateTime.now()});
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();
    _saveMessage(userMessage, true);

    final response = await aiService.sendMessage(userMessage);
    if (!mounted) return;

    if (response == "[ACTION: OPEN_TOUR_REQUESTS]") {
      final msg = _chosenLanguage == 'french'
          ? 'Parfait ! J\'ouvre le planificateur de visites pour vous... 📅'
          : 'Perfect! I am opening the Tour Scheduler for you right now... 📅';
      setState(() { _isTyping = false; _messages.add({'message': msg, 'isMe': false, 'time': DateTime.now()}); });
      _scrollToBottom();
      _saveMessage(msg, false);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TourRequestsScreen()));
      });
      return;
    } else if (response.startsWith("[ACTION: SEARCH_PROPERTIES: ")) {
      final query = response.replaceAll("[ACTION: SEARCH_PROPERTIES: ", "").replaceAll("]", "");
      final msg = _chosenLanguage == 'french'
          ? 'Bien sûr ! Voici les propriétés correspondant à "$query"... 🔍'
          : 'Absolutely! Let me pull up the properties matching "$query" for you right now... 🔍';
      setState(() { _isTyping = false; _messages.add({'message': msg, 'isMe': false, 'time': DateTime.now()}); });
      _scrollToBottom();
      _saveMessage(msg, false);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => ExploreScreen(searchQuery: query)));
      });
      return;
    }

    setState(() {
      _isTyping = false;
      _messages.add({'message': response, 'isMe': false, 'time': DateTime.now()});
    });
    _scrollToBottom();
    _saveMessage(response, false);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // ─── BUILD ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
      drawer: _buildDrawer(isDark),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
          : Column(children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) return _buildTypingIndicator(isDark);
                    final m = _messages[index];
                    if (m['isLanguagePrompt'] == true && !_languageChosen) {
                      return Column(children: [
                        _buildBubble(m['message'], false, m['time'], isDark),
                        const SizedBox(height: 12),
                        _buildLanguageButtons(isDark),
                      ]);
                    }
                    return _buildBubble(m['message'], m['isMe'], m['time'], isDark);
                  },
                ),
              ),
              _languageChosen ? _buildInput(isDark) : _buildInputPlaceholder(isDark),
            ]),
    );
  }

  // ─── DRAWER (Conversation History Sidebar) ───────────────────────────
  Widget _buildDrawer(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? Colors.grey[400]! : const Color(0xFF64748B);
    final divColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    return Drawer(
      backgroundColor: bgColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF1E3A5F)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _chosenLanguage == 'french' ? 'Conversations' : 'Conversations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: subColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(color: divColor, height: 1),

            // New Chat button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await _startNewSession();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF1E3A5F)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _chosenLanguage == 'french' ? 'Nouvelle conversation' : 'New Conversation',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                _chosenLanguage == 'french' ? 'Historique' : 'History',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor, letterSpacing: 0.8),
              ),
            ),

            // Session list
            Expanded(
              child: _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: subColor.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _chosenLanguage == 'french' ? 'Aucune conversation' : 'No conversations yet',
                            style: TextStyle(color: subColor, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        final data = session.data() as Map<String, dynamic>;
                        final title = (data['title'] as String?)?.isNotEmpty == true
                            ? data['title'] as String
                            : (_chosenLanguage == 'french' ? 'Conversation' : 'Conversation');
                        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
                        final timeStr = updatedAt != null
                            ? '${updatedAt.day}/${updatedAt.month}/${updatedAt.year} ${updatedAt.hour}:${updatedAt.minute.toString().padLeft(2, '0')}'
                            : '';
                        final isActive = session.id == _activeSessionId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Material(
                            color: isActive
                                ? const Color(0xFF8B5CF6).withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                Navigator.pop(context);
                                if (session.id != _activeSessionId) {
                                  await _loadSession(session.id);
                                  // Refresh sessions list after loading
                                  final sessionDocs = await FirebaseFirestore.instance
                                      .collection('ai_chats')
                                      .where('userId', isEqualTo: _resolvedId)
                                      .orderBy('updatedAt', descending: true)
                                      .get();
                                  if (mounted) setState(() => _sessions = sessionDocs.docs);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 16,
                                      color: isActive ? const Color(0xFF8B5CF6) : subColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                              color: isActive ? const Color(0xFF8B5CF6) : textColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (timeStr.isNotEmpty)
                                            Text(timeStr, style: TextStyle(fontSize: 10, color: subColor)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, size: 16, color: Colors.redAccent.withOpacity(0.7)),
                                      splashRadius: 18,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await _deleteSession(session.id);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDark) => AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF1E3A5F)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Home237 AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const Text('Always Online', style: TextStyle(fontSize: 12, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w500)),
          ]),
        ]),
        actions: [
          // History sidebar button
          Builder(builder: (ctx) => IconButton(
            icon: Icon(Icons.history, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            tooltip: _chosenLanguage == 'french' ? 'Historique' : 'History',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          )),
          // Clear chat button
          IconButton(
            icon: Icon(Icons.delete_outline, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            onPressed: _confirmClearChat,
          ),
        ],
      );

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_chosenLanguage == 'french' ? 'Effacer la conversation ?' : 'Clear conversation?'),
        content: Text(_chosenLanguage == 'french'
            ? 'Cela supprimera tous les messages. Cette action est irréversible.'
            : 'This will delete all messages. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_chosenLanguage == 'french' ? 'Annuler' : 'Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_activeSessionId != null) {
                await _deleteSession(_activeSessionId!);
              }
            },
            child: Text(_chosenLanguage == 'french' ? 'Effacer' : 'Clear', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ─── LANGUAGE BUTTONS ────────────────────────────────────────────────
  Widget _buildLanguageButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(children: [
        _langBtn('english', '🇬🇧', 'English', const [Color(0xFF1E3A5F), Color(0xFF1E3A5F)]),
        const SizedBox(height: 12),
        _langBtn('french', '🇫🇷', 'Français', const [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _langBtn(String lang, String flag, String label, List<Color> colors) {
    return GestureDetector(
      onTap: () => _selectLanguage(lang),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: colors[0].withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  // ─── INPUT ───────────────────────────────────────────────────────────
  Widget _buildInput(bool isDark) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 16, left: 16, right: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: _chosenLanguage == 'french' ? 'Posez votre question...' : 'Ask the AI anything...',
              hintStyle: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
              filled: true,
              fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              prefixIcon: Icon(Icons.auto_awesome, color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8), size: 20),
            ),
            maxLines: null,
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF1E3A5F)]), shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage),
        ),
      ]),
    );
  }

  Widget _buildInputPlaceholder(bool isDark) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, top: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05))),
      ),
      child: Center(child: Text('⬆️ Please select your preferred language above', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8), fontStyle: FontStyle.italic))),
    );
  }

  // ─── BUBBLE ──────────────────────────────────────────────────────────
  Widget _buildBubble(String message, bool isMe, DateTime time, bool isDark) {
    final timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF1E3A5F)]), shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text('AI Assistant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : const Color(0xFF64748B))),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF0EA5E9) : (isDark ? const Color(0xFF374151) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: Text(message, style: TextStyle(fontSize: 15, color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)), height: 1.4)),
                ),
                const SizedBox(height: 4),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(timeStr, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TYPING INDICATOR ────────────────────────────────────────────────
  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(width: 32, height: 32, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF1E3A5F)]), shape: BoxShape.circle), child: const Icon(Icons.smart_toy, color: Colors.white, size: 16)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF374151) : Colors.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 5, offset: const Offset(0, 2))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(0), const SizedBox(width: 4), _dot(1), const SizedBox(width: 4), _dot(2)]),
        ),
      ]),
    );
  }

  Widget _dot(int i) => TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        builder: (_, value, _) => Opacity(
          opacity: (value + (i * 0.3)) % 1.0,
          child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle)),
        ),
      );

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
