import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'auth_service.dart';
import 'property_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String? propertyTitle;
  final String? initialMessage;
  final String? initialImage;
  final String? propertyId;

  const ChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.propertyTitle,
    this.initialMessage,
    this.initialImage,
    this.propertyId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _initializeConversation();
  }

  Future<void> _initializeConversation() async {
    try {
      final currentUserId = authService.userId;
      if (currentUserId == null) {
        print('ChatScreen: No current user ID');
        return;
      }

      if (widget.recipientId.isEmpty || widget.recipientId == 'null') {
        print('ChatScreen: Invalid recipient ID');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Invalid recipient.')),
          );
        }
        return;
      }

      // Create conversation ID (alphabetically sorted user IDs)
      final ids = [currentUserId, widget.recipientId]..sort();
      final conversationId = '${ids[0]}_${ids[1]}';

      setState(() => _conversationId = conversationId);

      // Create conversation if it doesn't exist
      final convRef = FirebaseFirestore.instance.collection('conversations').doc(conversationId);
      final convDoc = await convRef.get();

      if (!convDoc.exists) {
        await convRef.set({
          'participants': ids,
          'participantNames': {
            currentUserId: authService.userName ?? 'User',
            widget.recipientId: widget.recipientName,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'unreadCount_$currentUserId': 0,
          'unreadCount_${widget.recipientId}': 0,
        });
        
        // Send initial message if provided for new conversation
        if ((widget.initialMessage != null && widget.initialMessage!.isNotEmpty) || (widget.initialImage != null)) {
          _messageController.text = widget.initialMessage ?? '';
          _sendMessage(imageUrl: widget.initialImage, propertyId: widget.propertyId);
        }
      } else {
        // Reset unread count for current user
        await convRef.update({
          'unreadCount_$currentUserId': 0,
        });
      }
    } catch (e) {
      print('Error initializing conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chat: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage({String? imageUrl, String? propertyId}) async {
    final message = _messageController.text.trim();
    if (message.isEmpty && imageUrl == null) return;
    if (_conversationId == null) return;
    
    _messageController.clear();

    try {
      final currentUserId = authService.userId;
      if (currentUserId == null) return;

      // Add message to conversation
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'senderName': authService.userName ?? 'User',
      'text': message,
      'imageUrl': imageUrl,
      'propertyId': propertyId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    // Update last message in conversation
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(_conversationId)
        .update({
      'lastMessage': imageUrl != null && message.isEmpty ? '📷 Image' : message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount_${widget.recipientId}': FieldValue.increment(1),
    });

      // Send notification to recipient
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(widget.recipientId)
          .collection('items')
          .add({
        'title': 'New Message',
        'message': '${authService.userName}: $message',
        'type': 'message',
        'read': false,
        'senderId': currentUserId,
        'conversationId': _conversationId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.recipientName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (widget.propertyTitle != null)
              Text(
                widget.propertyTitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () {
              // TODO: Implement call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Call feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _conversationId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(_conversationId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                final groupedNodes = _groupMessagesByDate(messages);

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Reset unread count since we are viewing the chat
                  if (_conversationId != null && authService.userId != null) {
                    FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(_conversationId)
                        .update({'unreadCount_${authService.userId}': 0}).catchError((_) {});
                  }
                });

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
                  final messageId = doc.id;
                  final isMe = messageData['senderId'] == authService.userId;
                  final timestamp = messageData['timestamp'] as Timestamp?;
                  final reactions = messageData['reactions'] as Map<String, dynamic>? ?? {};
                  final imageUrl = messageData['imageUrl'] as String?;
                  final propId = messageData['propertyId'] as String?;

                  return _buildMessageBubble(
                    messageData['text'] ?? '',
                    isMe,
                    timestamp,
                    isDark,
                    messageId,
                    reactions,
                    imageUrl: imageUrl,
                    propertyId: propId,
                  );
                },
                );
              },
            ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF3B82F6),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    String text,
    bool isMe,
    Timestamp? timestamp,
    bool isDark,
    String messageId,
    Map<String, dynamic> reactions, {
    String? imageUrl,
    String? propertyId,
  }) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showReactionPicker(messageId, reactions),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              // Reduced vertical padding if there's an image to make it look tighter
              padding: EdgeInsets.fromLTRB(hasImage ? 4 : 16, hasImage ? 4 : 10, hasImage ? 4 : 16, 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF3B82F6)
                    : isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage) ...[
                    GestureDetector(
                      onTap: propertyId != null ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PropertyDetailsScreen(propertyId: propertyId),
                          ),
                        );
                      } : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 180,
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 100,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (text.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hasImage ? 8 : 0),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 15,
                          color: isMe
                              ? Colors.white
                              : isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  if (timestamp != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: hasImage ? 8 : 0),
                      child: Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (reactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    if (_conversationId == null) return;
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
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'reactions': updatedReactions});
    } catch (e) {
      debugPrint("Error updating reaction: $e");
    }
  }

  List<dynamic> _groupMessagesByDate(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return [];

    final grouped = <dynamic>[];
    String? lastDate;

    // Messages are descending: true, so the first in list (index 0) is the newest
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

  String _formatTimestamp(Timestamp timestamp) {
    final messageTime = timestamp.toDate();
    return '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}