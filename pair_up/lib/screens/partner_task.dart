// partner_task.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../themes/theme.dart';
import 'create_task.dart';
import 'partner_reading_list.dart';

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

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Success"),
            content: Text(
              "$numberOfTasksToDelete task(s) deleted successfully.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
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
            child: const Text("Unpair", style: TextStyle(color: Colors.red)),
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
        actions: _isDeleting
            ? [
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
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _deleteTasks();
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
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
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: 'Select tasks to delete',
                  onPressed: () {
                    setState(() => _isDeleting = true);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.link_off),
                  tooltip: "Unpair",
                  onPressed: () => _unpairPartner(context),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.normal,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
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
                    final String formattedDate = DateFormat.yMMMd().format(
                      dueDate,
                    );

                    return Card(
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
                            Text(
                              taskData['title'],
                              style: TextStyle(
                                decoration: isCompletedByUser
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
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
                        trailing: Text(formattedDate),
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
