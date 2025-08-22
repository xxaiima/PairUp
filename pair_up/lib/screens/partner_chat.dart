// partner_chat_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../themes/theme.dart';

class PartnerChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;

  const PartnerChatScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
  });

  @override
  State<PartnerChatScreen> createState() => _PartnerChatScreenState();
}

class _PartnerChatScreenState extends State<PartnerChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _messageFocusNode = FocusNode();

  String? _chatDocId;
  bool _isLoading = true;
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _getChatDocumentId();
    _markChatAsRead();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _messageFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getChatDocumentId() async {
    final currentUserUid = _auth.currentUser!.uid;
    final partnerId = widget.partnerId;

    final participants = [currentUserUid, partnerId]..sort();
    final chatDocId = participants.join('_');

    final chatDocRef = _db.collection('chats').doc(chatDocId);
    final chatDoc = await chatDocRef.get();

    if (!chatDoc.exists) {
      await chatDocRef.set({
        'participants': participants,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      setState(() {
        _chatDocId = chatDocId;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatDocId == null) return;

    final user = _auth.currentUser!;
    final messageText = _messageController.text.trim();

    final batch = _db.batch();

    // Check for editing mode
    if (_editingMessageId != null) {
      batch.update(
        _db
            .collection('chats')
            .doc(_chatDocId)
            .collection('messages')
            .doc(_editingMessageId),
        {'text': messageText, 'edited': true},
      );
      if (mounted) {
        setState(() {
          _editingMessageId = null;
          _messageController.clear();
        });
      }
    } else {
      // Add the new message
      final messageRef = _db
          .collection('chats')
          .doc(_chatDocId)
          .collection('messages')
          .doc();
      batch.set(messageRef, {
        'senderId': user.uid,
        'senderName': user.displayName ?? 'Anonymous',
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'edited': false,
        'deliveredTo': [user.uid],
        'seenBy': [user.uid],
      });

      // Add a notification for the partner
      final partnerNotificationRef = _db
          .collection('users')
          .doc(widget.partnerId)
          .collection('notifications')
          .doc();

      batch.set(partnerNotificationRef, {
        'type': 'chat_message',
        'message':
            '${user.displayName?.split(' ').first ?? 'Someone'} sent you a message.',
        'initials': user.displayName?.split(' ').first.substring(0, 1) ?? '?',
        'senderId': user.uid,
        'senderName': user.displayName ?? 'Anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the partner's unread notifications count
      batch.update(_db.collection('users').doc(widget.partnerId), {
        'unreadNotifications': FieldValue.increment(1),
      });

      // Update the partner's chat unread status
      final unreadStatusRef = _db
          .collection('chats')
          .doc(_chatDocId)
          .collection('unread_status')
          .doc(widget.partnerId);
      batch.set(unreadStatusRef, {
        'userId': widget.partnerId,
        'unreadCount': FieldValue.increment(1),
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _messageController.clear();
    }

    await batch.commit();

    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _markChatAsRead() async {
    final currentUserUid = _auth.currentUser!.uid;
    final partnerId = widget.partnerId;
    final chatDocId = ([currentUserUid, partnerId]..sort()).join('_');

    final unreadStatusRef = _db
        .collection('chats')
        .doc(chatDocId)
        .collection('unread_status')
        .doc(currentUserUid);

    // Reset unread count for current user
    await unreadStatusRef.set({
      'userId': currentUserUid,
      'unreadCount': 0,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deleteMessage(String messageId) async {
    await _db
        .collection('chats')
        .doc(_chatDocId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  void _onLongPressMessage(String messageId, String messageText) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMessageId = messageId;
                    _messageController.text = messageText;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: messageText));
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message copied to clipboard'),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete,
                  color: Color.fromARGB(255, 218, 132, 160),
                ),
                title: const Text('Delete'),
                onTap: () {
                  _deleteMessage(messageId);
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message deleted')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // This function updates the message status to seen
  Future<void> _markMessageAsSeen(String messageId) async {
    final currentUserUid = _auth.currentUser!.uid;
    await _db
        .collection('chats')
        .doc(_chatDocId)
        .collection('messages')
        .doc(messageId)
        .update({
          'seenBy': FieldValue.arrayUnion([currentUserUid]),
        });
  }

  // This function updates the message status to delivered
  Future<void> _markMessageAsDelivered(String messageId) async {
    final currentUserUid = _auth.currentUser!.uid;
    await _db
        .collection('chats')
        .doc(_chatDocId)
        .collection('messages')
        .doc(messageId)
        .update({
          'deliveredTo': FieldValue.arrayUnion([currentUserUid]),
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.partnerName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.partnerName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('chats')
                  .doc(_chatDocId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;
                final currentUserUid = _auth.currentUser!.uid;

                // Mark messages as delivered and seen as they are loaded
                messages.forEach((doc) {
                  final messageData = doc.data() as Map<String, dynamic>;
                  final deliveredTo =
                      (messageData['deliveredTo'] as List?) ?? [];
                  final seenBy = (messageData['seenBy'] as List?) ?? [];
                  if (messageData['senderId'] != currentUserUid) {
                    if (!deliveredTo.contains(currentUserUid)) {
                      _markMessageAsDelivered(doc.id);
                    }
                    if (!seenBy.contains(currentUserUid)) {
                      _markMessageAsSeen(doc.id);
                    }
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final messageId = messageDoc.id;
                    final message = messageDoc.data() as Map<String, dynamic>;
                    final isCurrentUser = message['senderId'] == currentUserUid;
                    final isEdited = message['edited'] ?? false;
                    final deliveredTo = (message['deliveredTo'] as List?) ?? [];
                    final seenBy = (message['seenBy'] as List?) ?? [];

                    final timestamp = message['timestamp'] as Timestamp?;
                    final timeString = timestamp != null
                        ? DateFormat.jm().format(timestamp.toDate())
                        : '';

                    final isDelivered = deliveredTo.contains(widget.partnerId);
                    final isSeen = seenBy.contains(widget.partnerId);

                    return GestureDetector(
                      onLongPress: isCurrentUser
                          ? () =>
                                _onLongPressMessage(messageId, message['text'])
                          : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: isCurrentUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? AppTheme.primaryColor
                                      : AppTheme.secondaryColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: isCurrentUser
                                        ? const Radius.circular(20)
                                        : const Radius.circular(0),
                                    bottomRight: isCurrentUser
                                        ? const Radius.circular(0)
                                        : const Radius.circular(20),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message['text'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isEdited)
                                          const Text(
                                            'edited ',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white54,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        Text(
                                          timeString,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white.withOpacity(
                                              0.7,
                                            ),
                                          ),
                                        ),
                                        if (isCurrentUser) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            isSeen
                                                ? Icons.done_all
                                                : Icons.done,
                                            size: 14,
                                            color: isSeen
                                                ? Colors.lightBlueAccent
                                                : Colors.white54,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    decoration: InputDecoration(
                      hintText: "Send a message...",
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(
                    _editingMessageId != null ? Icons.done : Icons.send,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
    );
  }
}
