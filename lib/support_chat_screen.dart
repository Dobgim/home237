import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastAutoReplyTime;

  @override
  void initState() {
    super.initState();
    _ensureChatExists();
  }

  // Ensure chat document exists with user metadata
  Future<void> _ensureChatExists() async {
    final chatRef = FirebaseFirestore.instance
        .collection('support_chats')
        .doc(authService.userId);

    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      await chatRef.set({
        'userId': authService.userId,
        'userName': authService.userName ?? 'User',
        'userEmail': authService.userEmail ?? '',
        'userRole': authService.userRole.toString().split('.').last,
        'status': 'open',
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadByAdmin': 0,
        'unreadByUser': 0,
      });
    } else {
      // If it exists, reset unread messages for the user
      await chatRef.update({'unreadByUser': 0});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support Team',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const Text(
                  'Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_chats')
                  .doc(authService.userId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                final groupedNodes = _groupMessagesByDate(messages);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: groupedNodes.length,
                  itemBuilder: (context, index) {
                    final node = groupedNodes[index];
                    if (node is String) {
                      return _buildDateHeader(node, isDark);
                    }
                    
                    final doc = node as DocumentSnapshot;
                    final messageData = doc.data() as Map<String, dynamic>;
                    final isMe = messageData['senderId'] == authService.userId;
                    final isAdmin = messageData['isAdmin'] == true;
                    return _buildMessageBubble(doc.id, messageData, isMe, isAdmin, isDark);
                  },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 16,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF374151) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _groupMessagesByDate(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return [];

    final grouped = <dynamic>[];
    String? lastDate;

    // Messages are descending: true, so the first in list is the newest
    for (var i = 0; i < docs.length; i++) {
      final doc = docs[i];
      grouped.add(doc);

      final timestamp = doc['timestamp'] as Timestamp?;
      if (timestamp == null) continue;

      final dateStr = _getDateHeader(timestamp.toDate());
      
      String? nextDateStr;
      if (i + 1 < docs.length) {
        final nextTimestamp = docs[i+1]['timestamp'] as Timestamp?;
        if (nextTimestamp != null) {
          nextDateStr = _getDateHeader(nextTimestamp.toDate());
        }
      }

      // If this is the last message or the next message is on a different day,
      // add the date header. Because reverse: true, this header will appear ABOVE
      // the messages of this day in the visual list.
      if (dateStr != nextDateStr) {
        grouped.add(dateStr);
      }
    }

    return grouped;
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return 'Today';
    if (messageDate == yesterday) return 'Yesterday';
    
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    
    if (now.difference(messageDate).inDays < 7) {
      return weekdays[date.weekday - 1];
    }
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  Widget _buildDateHeader(String date, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          date,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String messageId, Map<String, dynamic> messageData, bool isMe, bool isAdmin, bool isDark) {
    final message = messageData['message'] ?? '';
    final timestamp = messageData['timestamp'] as Timestamp?;
    final senderName = messageData['senderName'] ?? 'Support';
    final reactions = messageData['reactions'] as Map<String, dynamic>? ?? {};

    String timeStr = '';
    if (timestamp != null) {
      final time = timestamp.toDate();
      timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: () => _showReactionPicker(messageId, reactions),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF0EA5E9) : (isDark ? const Color(0xFF374151) : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 15,
                        color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
                if (reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Wrap(
                      spacing: 4,
                      children: reactions.entries.map((entry) {
                        final emoji = entry.key;
                        final uids = List<String>.from(entry.value);
                        if (uids.isEmpty) return const SizedBox.shrink();
                        final isMyReaction = uids.contains(authService.userId);

                        return GestureDetector(
                          onTap: () => _addReaction(messageId, emoji, reactions),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMyReaction 
                                  ? const Color(0xFF3B82F6).withOpacity(0.2)
                                  : isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isMyReaction ? const Color(0xFF3B82F6) : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 12)),
                                if (uids.length > 1) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${uids.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
              child: Text(
                (authService.userName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0EA5E9),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Add message to subcollection
      final messageRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(authService.userId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'message': message,
        'senderId': authService.userId,
        'senderName': authService.userName,
        'isAdmin': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update chat metadata
      final chatRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(authService.userId);

      batch.update(chatRef, {
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadByAdmin': FieldValue.increment(1),
        'status': 'open',
      });

      await batch.commit();

      // Trigger Auto-Reply
      _triggerAutoReply();

      // Auto-scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  void _triggerAutoReply() {
    final now = DateTime.now();
    // Only auto-reply if we haven't in the last hour
    if (_lastAutoReplyTime != null && now.difference(_lastAutoReplyTime!) < const Duration(hours: 1)) {
      return;
    }

    _lastAutoReplyTime = now;

    // Wait 2 seconds to feel more natural
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;

      try {
        final autoMessage = "Hello! 👋 Thank you for contacting Home237 Support. One of our agents will be with you shortly. In the meantime, please feel free to describe your issue or inquiry in detail so we can help you better.";
        
        final batch = FirebaseFirestore.instance.batch();
        final chatRef = FirebaseFirestore.instance.collection('support_chats').doc(authService.userId);
        final messageRef = chatRef.collection('messages').doc();

        batch.set(messageRef, {
          'message': autoMessage,
          'senderId': 'system_support',
          'senderName': 'Support Team',
          'isAdmin': true,
          'timestamp': FieldValue.serverTimestamp(),
        });

        batch.update(chatRef, {
          'lastMessage': autoMessage,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadByUser': FieldValue.increment(1),
        });

        await batch.commit();
      } catch (e) {
        print('Error sending auto-reply: $e');
      }
    });
  }

  void _showReactionPicker(String messageId, Map<String, dynamic> currentReactions) {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "React to message",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emojis.map((emoji) {
                final uids = List<String>.from(currentReactions[emoji] ?? []);
                final isSelected = uids.contains(authService.userId);

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _addReaction(messageId, emoji, currentReactions);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? const Color(0xFF3B82F6).withOpacity(0.1)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _addReaction(String messageId, String emoji, Map<String, dynamic> currentReactions) async {
    final myId = authService.userId;
    if (myId == null) return;

    Map<String, dynamic> updatedReactions = Map<String, dynamic>.from(currentReactions);
    List<String> userList = List<String>.from(updatedReactions[emoji] ?? []);

    if (userList.contains(myId)) {
      userList.remove(myId);
    } else {
      userList.add(myId);
    }

    if (userList.isEmpty) {
      updatedReactions.remove(emoji);
    } else {
      updatedReactions[emoji] = userList;
    }

    try {
      await FirebaseFirestore.instance
          .collection('support_chats')
          .doc(authService.userId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions': updatedReactions});
    } catch (e) {
      print("Error updating reaction: $e");
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
