// partner_task.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../themes/theme.dart';
import 'create_task.dart';
import 'partner_reading_list.dart';
import 'partner_chat.dart';
import 'edit_task.dart';

class PartnerTaskScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;

  const PartnerTaskScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
  });

  @override
  State<PartnerTaskScreen> createState() => _PartnerTaskScreenState();
}

class _PartnerTaskScreenState extends State<PartnerTaskScreen> {
  bool _isDeleting = false;
  final List<String> _selectedTaskIds = [];

  Future<void> _deleteTasks() async {
    if (_selectedTaskIds.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser!;
    final currentUserName = currentUser.displayName ?? 'A User';
    final currentUserFirstName = currentUserName.split(' ').first;
    final numberOfTasksToDelete = _selectedTaskIds.length;

    try {
      final tasksQuery = await db
          .collection('tasks')
          .where(FieldPath.documentId, whereIn: _selectedTaskIds)
          .get();

      final batch = db.batch();

      for (final taskDoc in tasksQuery.docs) {
        final taskData = taskDoc.data();
        final taskTitle = taskData['title'] ?? 'a task';

        final partnerNotificationRef = db
            .collection('users')
            .doc(widget.partnerId)
            .collection('notifications')
            .doc();

        batch.set(partnerNotificationRef, {
          'type': 'task_deleted',
          'message': '$currentUserFirstName deleted the task: "$taskTitle".',
          'initials': currentUserFirstName.substring(0, 1),
          'senderId': currentUser.uid,
          'senderName': currentUserName,
          'timestamp': FieldValue.serverTimestamp(),
        });

        final partnerUserRef = db.collection('users').doc(widget.partnerId);
        batch.update(partnerUserRef, {
          'unreadNotifications': FieldValue.increment(1),
        });

        batch.delete(taskDoc.reference);
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          _selectedTaskIds.clear();
          _isDeleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$numberOfTasksToDelete task(s) deleted successfully.',
            ),
            backgroundColor: const Color.fromARGB(255, 184, 155, 218),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to delete tasks: $e")));
      }
    }
  }

  Future<void> _unpairPartner(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final db = FirebaseFirestore.instance;
    final pairedParticipants = [currentUser.uid, widget.partnerId]..sort();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Unpair with ${widget.partnerName}?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text(
              "Unpair",
              style: TextStyle(color: Color.fromARGB(255, 218, 132, 160)),
            ),
            onPressed: () async {
              await db.runTransaction((transaction) async {
                final tasksQuery = await db
                    .collection('tasks')
                    .where('participants', isEqualTo: pairedParticipants)
                    .where('isPaired', isEqualTo: true)
                    .get();

                for (final doc in tasksQuery.docs) {
                  transaction.delete(doc.reference);
                }

                final currentUserNotificationsQuery = await db
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('notifications')
                    .where('senderId', isEqualTo: widget.partnerId)
                    .get();

                for (final doc in currentUserNotificationsQuery.docs) {
                  transaction.delete(doc.reference);
                }

                final partnerNotificationsQuery = await db
                    .collection('users')
                    .doc(widget.partnerId)
                    .collection('notifications')
                    .where('senderId', isEqualTo: currentUser.uid)
                    .get();

                for (final doc in partnerNotificationsQuery.docs) {
                  transaction.delete(doc.reference);
                }

                transaction.update(
                  db.collection('users').doc(currentUser.uid),
                  {
                    'partners': FieldValue.arrayRemove([widget.partnerId]),
                  },
                );
                transaction.update(
                  db.collection('users').doc(widget.partnerId),
                  {
                    'partners': FieldValue.arrayRemove([currentUser.uid]),
                  },
                );
              });
              if (context.mounted) {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final String currentUserFirstName =
        currentUser.displayName?.split(' ').first ?? 'You';
    final String partnerFirstName = widget.partnerName.split(' ').first;
    final participants = [currentUser.uid, widget.partnerId]..sort();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(([currentUser.uid, widget.partnerId]..sort()).join('_'))
                  .collection('unread_status')
                  .where('userId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                bool hasUnread = false;
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final unreadDoc = snapshot.data!.docs.first;
                  final data = unreadDoc.data() as Map<String, dynamic>?;
                  if (data != null) {
                    hasUnread = data['unreadCount'] > 0;
                  }
                }
                return Stack(
                  children: [
                    const Icon(Icons.forum_rounded, size: 35.0),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            tooltip: "Chat with ${widget.partnerName}",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PartnerChatScreen(
                    partnerId: widget.partnerId,
                    partnerName: widget.partnerName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PartnerReadingListScreen(
                              partnerId: widget.partnerId,
                              partnerName: widget.partnerName,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Tap to see $partnerFirstName's books >",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.normal,
                                color: AppTheme.primaryColor,
                              ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isDeleting)
                          IconButton(
                            icon: const Icon(Icons.delete_sweep),
                            tooltip: 'Select tasks to delete',
                            onPressed: () {
                              setState(() => _isDeleting = true);
                            },
                          ),
                        if (!_isDeleting)
                          IconButton(
                            icon: const Icon(Icons.link_off),
                            tooltip: "Unpair",
                            onPressed: () => _unpairPartner(context),
                          ),
                      ],
                    ),
                    if (_isDeleting)
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete Selected Tasks',
                            onPressed: () {
                              if (_selectedTaskIds.isNotEmpty) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Tasks?'),
                                    content: Text(
                                      'Are you sure you want to delete ${_selectedTaskIds.length} task(s)?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _deleteTasks();
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Color.fromARGB(
                                              255,
                                              218,
                                              132,
                                              160,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                setState(() => _isDeleting = false);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Cancel Deletion',
                            onPressed: () {
                              setState(() {
                                _isDeleting = false;
                                _selectedTaskIds.clear();
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .where('participants', isEqualTo: participants)
                  .where('isPaired', isEqualTo: true)
                  .orderBy('dueDate')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tasks yet. Tap "+" to add one!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                final tasks = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final taskData =
                        tasks[index].data() as Map<String, dynamic>;
                    final String taskId = tasks[index].id;
                    final bool isCompletedByUser =
                        taskData['status']?[currentUser.uid] == 'completed';
                    final bool isCompletedByPartner =
                        taskData['status']?[widget.partnerId] == 'completed';
                    final DateTime dueDate = (taskData['dueDate'] as Timestamp)
                        .toDate();
                    final bool isOverdue =
                        dueDate.isBefore(DateTime.now()) &&
                        !isSameDay(dueDate, DateTime.now());
                    final String formattedDate = DateFormat.yMMMd().format(
                      dueDate,
                    );
                    final bool hasNotes =
                        taskData['notes'] != null &&
                        (taskData['notes'] as String).isNotEmpty;

                    return Card(
                      color: isOverdue && !isCompletedByUser
                          ? const Color.fromARGB(255, 229, 130, 130)
                          : null,
                      child: ListTile(
                        leading: _isDeleting
                            ? Checkbox(
                                value: _selectedTaskIds.contains(taskId),
                                activeColor: AppTheme.primaryColor,
                                checkColor: AppTheme.textOnPrimary,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedTaskIds.add(taskId);
                                    } else {
                                      _selectedTaskIds.remove(taskId);
                                    }
                                  });
                                },
                              )
                            : Checkbox(
                                value: isCompletedByUser,
                                activeColor: AppTheme.primaryColor,
                                checkColor: AppTheme.textOnPrimary,
                                onChanged: (bool? value) async {
                                  final newStatus = value == true
                                      ? 'completed'
                                      : 'pending';

                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('tasks')
                                        .doc(taskId)
                                        .update({
                                          'status.${currentUser.uid}':
                                              newStatus,
                                        });

                                    final currentUserName =
                                        currentUser.displayName ?? 'A User';
                                    final currentUserFirstName = currentUserName
                                        .split(' ')
                                        .first;
                                    final taskTitle =
                                        taskData['title'] ?? 'a task';
                                    if (value == true) {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.partnerId)
                                          .collection('notifications')
                                          .add({
                                            'taskId': taskId,
                                            'type': 'task_completed',
                                            'message':
                                                '$currentUserFirstName completed the task "$taskTitle".',
                                            'initials': currentUserFirstName
                                                .substring(0, 1),
                                            'senderId': currentUser.uid,
                                            'senderName': currentUserName,
                                            'timestamp':
                                                FieldValue.serverTimestamp(),
                                          });

                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.partnerId)
                                          .update({
                                            'unreadNotifications':
                                                FieldValue.increment(1),
                                          });
                                    } else {
                                      final notificationsQuery =
                                          await FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(widget.partnerId)
                                              .collection('notifications')
                                              .where(
                                                'taskId',
                                                isEqualTo: taskId,
                                              )
                                              .where(
                                                'type',
                                                isEqualTo: 'task_completed',
                                              )
                                              .where(
                                                'senderId',
                                                isEqualTo: currentUser.uid,
                                              )
                                              .limit(1)
                                              .get();

                                      for (final doc
                                          in notificationsQuery.docs) {
                                        await doc.reference.delete();
                                      }

                                      if (notificationsQuery.docs.isNotEmpty) {
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(widget.partnerId)
                                            .update({
                                              'unreadNotifications':
                                                  FieldValue.increment(-1),
                                            });
                                      }
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to update task: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  // Add Expanded here
                                  child: Text(
                                    taskData['title'],
                                    style: TextStyle(
                                      decoration: isCompletedByUser
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasNotes)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8.0),
                                    child: Icon(
                                      Icons.description_outlined,
                                      size: 16,
                                      color: Color(0xFF0A2342),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Opacity(
                                  opacity: isCompletedByUser ? 0.3 : 1.0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.8,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      currentUserFirstName.substring(0, 1),
                                      style: TextStyle(
                                        color: AppTheme.textOnPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Opacity(
                                  opacity: isCompletedByPartner ? 0.3 : 1.0,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryColor
                                          .withOpacity(0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      partnerFirstName.substring(0, 1),
                                      style: TextStyle(
                                        color: AppTheme.textOnPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: _isDeleting
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(formattedDate),
                                  const SizedBox(width: 8),
                                  // ADDED: The Edit button
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.grey.shade600,
                                    ),
                                    tooltip: 'Edit Task',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditTaskScreen(
                                            taskId: taskId,
                                            taskData: taskData,
                                          ),
                                        ),
                                      );
                                    },
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
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateTaskScreen(
                partnerName: widget.partnerName,
                partnerId: widget.partnerId,
              ),
            ),
          );
        },
        backgroundColor: const Color.fromARGB(246, 202, 213, 241),
        foregroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
