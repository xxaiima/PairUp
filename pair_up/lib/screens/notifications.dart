// notifications.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../themes/theme.dart';
import 'partner_task.dart';
import 'partner_chat.dart';
import 'partner_reading_list.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _currentUser = FirebaseAuth.instance.currentUser!;
  final List<String> _selectedNotificationIds = [];
  bool _isSelecting = false;

  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkNotificationSetting();
  }

  Future<void> _checkNotificationSetting() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .get();

    bool isEnabled = true;
    if (userDoc.exists && userDoc.data() != null) {
      isEnabled = userDoc.data()!['pushNotificationsEnabled'] ?? true;
    }

    if (mounted) {
      setState(() {
        _notificationsEnabled = isEnabled;
        _isLoading = false;
      });

      if (isEnabled) {
        _markNotificationsAsRead();
      }
    }
  }

  void _markNotificationsAsRead() {
    FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).update(
      {'unreadNotifications': 0},
    );
  }

  Future<void> _deleteSelectedNotifications() async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    for (final notificationId in _selectedNotificationIds) {
      final notificationRef = db
          .collection('users')
          .doc(_currentUser.uid)
          .collection('notifications')
          .doc(notificationId);
      batch.delete(notificationRef);
    }

    await batch.commit();

    if (mounted) {
      setState(() {
        _selectedNotificationIds.clear();
        _isSelecting = false;
      });
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      if (!_isSelecting) {
        _selectedNotificationIds.clear();
      }
    });
  }

  void _toggleNotificationSelection(String notificationId) {
    setState(() {
      if (_selectedNotificationIds.contains(notificationId)) {
        _selectedNotificationIds.remove(notificationId);
      } else {
        _selectedNotificationIds.add(notificationId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: _isSelecting
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedNotificationIds.isNotEmpty
                      ? _deleteSelectedNotifications
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancel',
                  onPressed: _toggleSelectionMode,
                ),
              ]
            : _notificationsEnabled
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Select notifications to delete',
                  onPressed: () {
                    _toggleSelectionMode();
                  },
                ),
              ]
            : [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notificationsEnabled
          ? _buildNotificationsList()
          : _buildNotificationsDisabledMessage(),
    );
  }

  Widget _buildNotificationsDisabledMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Notifications are turned off.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'You can turn them back on in the Settings screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return Column(
      children: [
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser.uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No new notifications.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final notifications = snapshot.data!.docs;

              return ListView.separated(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notificationDoc = notifications[index];
                  final notificationId = notificationDoc.id;
                  final notificationData =
                      (notificationDoc.data() as Map<String, dynamic>?) ?? {};
                  final String type = notificationData['type'] ?? 'general';
                  final String status = notificationData['status'] ?? '';

                  final timestamp = notificationData['timestamp'] as Timestamp?;
                  final timeString = timestamp != null
                      ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                      : 'Just now';

                  if (type == 'partner_request' && status == 'pending') {
                    return const SizedBox.shrink();
                  } else {
                    return ListTile(
                      leading: _isSelecting
                          ? Checkbox(
                              activeColor: AppTheme.primaryColor,
                              checkColor: AppTheme.textOnPrimary,
                              value: _selectedNotificationIds.contains(
                                notificationId,
                              ),
                              onChanged: (_) =>
                                  _toggleNotificationSelection(notificationId),
                            )
                          : CircleAvatar(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: AppTheme.textOnPrimary,
                              child: Text(
                                notificationData['initials'] ?? '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                      title: Text(
                        notificationData['message'] ?? 'New notification.',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                      subtitle: Text(
                        timeString,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        if (_isSelecting) {
                          _toggleNotificationSelection(notificationId);
                        } else {
                          final type = notificationData['type'] as String?;
                          final partnerId =
                              notificationData['senderId'] as String?;
                          final partnerName =
                              notificationData['senderName'] as String?;

                          if (partnerId != null &&
                              partnerName != null &&
                              context.mounted) {
                            if (type == 'task_created' ||
                                type == 'task_completed' ||
                                type == 'task_deleted') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PartnerTaskScreen(
                                    partnerId: partnerId,
                                    partnerName: partnerName,
                                  ),
                                ),
                              );
                            } else if (type == 'chat_message') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PartnerChatScreen(
                                    partnerId: partnerId,
                                    partnerName: partnerName,
                                  ),
                                ),
                              );
                            } else if (type == 'book_rated' ||
                                type == 'book_shared') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PartnerReadingListScreen(
                                        partnerId: partnerId,
                                        partnerName: partnerName,
                                      ),
                                ),
                              );
                            } /*else if (type == 'book_recommended' ||
                                type == 'book_liked') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BooksScreen(),
                                ),
                              );
                            }*/
                          }
                        }
                      },
                      onLongPress: () {
                        if (!_isSelecting) {
                          _toggleSelectionMode();
                          _toggleNotificationSelection(notificationId);
                        }
                      },
                    );
                  }
                },
                separatorBuilder: (context, index) => const Divider(height: 1),
              );
            },
          ),
        ),
      ],
    );
  }
}
