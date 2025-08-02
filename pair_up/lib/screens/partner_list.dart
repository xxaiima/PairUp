// partner_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_partner.dart';
import 'notifications.dart';
import 'partner_task.dart';
import '../themes/theme.dart';

class PartnerListScreen extends StatelessWidget {
  const PartnerListScreen({super.key});

  Future<void> _unpairPartner(
    BuildContext context,
    String partnerId,
    String partnerName,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final db = FirebaseFirestore.instance;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Unpair with $partnerName?"),
        content: const Text(
          "This action cannot be undone. All shared tasks will be deleted.",
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text("Unpair", style: TextStyle(color: Colors.red)),
            onPressed: () async {
              await db.runTransaction((transaction) async {
                final pairedParticipants = [currentUser.uid, partnerId]..sort();

                final tasksQuery = await db
                    .collection('tasks')
                    .where('participants', isEqualTo: pairedParticipants)
                    .where('isPaired', isEqualTo: true)
                    .get();

                for (final doc in tasksQuery.docs) {
                  transaction.delete(doc.reference);
                }

                transaction.update(
                  db.collection('users').doc(currentUser.uid),
                  {
                    'partners': FieldValue.arrayRemove([partnerId]),
                  },
                );
                transaction.update(db.collection('users').doc(partnerId), {
                  'partners': FieldValue.arrayRemove([currentUser.uid]),
                });
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Unpaired with $partnerName")),
                );
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRequest(String senderId, String requestId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final db = FirebaseFirestore.instance;

    await db.runTransaction((transaction) async {
      transaction.update(db.collection('users').doc(currentUser.uid), {
        'partners': FieldValue.arrayUnion([senderId]),
      });
      transaction.update(db.collection('users').doc(senderId), {
        'partners': FieldValue.arrayUnion([currentUser.uid]),
      });
      transaction.delete(db.collection('partner_requests').doc(requestId));
    });
  }

  Future<void> _declineRequest(String requestId) async {
    await FirebaseFirestore.instance
        .collection('partner_requests')
        .doc(requestId)
        .delete();
  }

  Widget _buildPendingRequests(BuildContext context, String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('partner_requests')
          .where('receiverId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final requests = snapshot.data!.docs;
        return Container(
          padding: const EdgeInsets.all(16.0),
          color: const Color.fromARGB(246, 202, 213, 241),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pending Requests",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: requests.map((request) {
                  final senderName = request['senderName'] ?? 'Someone';
                  final senderId = request['senderId'];
                  final requestId = request.id;
                  final initials = senderName.isNotEmpty
                      ? senderName.substring(0, 1).toUpperCase()
                      : '?';
                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        child: Text(initials),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$senderName wants to connect.",
                          style: TextStyle(color: AppTheme.primaryColor),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Color.fromARGB(255, 68, 138, 70),
                        ),
                        onPressed: () => _acceptRequest(senderId, requestId),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.cancel,
                          color: Color.fromARGB(255, 122, 34, 27),
                        ),
                        onPressed: () => _declineRequest(requestId),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "No partners yet",
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> avatarColors = const [
      Color(0xFF8B4513),
      Color(0xFF2E8B57),
      Color(0xFF4682B4),
      Color(0xFFD2691E),
      Color(0xFF6A5ACD),
    ];
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Partners"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, thickness: 1),
          _buildPendingRequests(context, currentUser.uid),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildEmptyState(context);
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final List<dynamic> partners = userData['partners'] ?? [];

                if (partners.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: partners.length,
                  itemBuilder: (context, index) {
                    final partnerId = partners.elementAt(index) as String;
                    final pairedParticipants = [currentUser.uid, partnerId]
                      ..sort();
                    final color = avatarColors.elementAt(
                      index % avatarColors.length,
                    );

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('tasks')
                          .where('participants', isEqualTo: pairedParticipants)
                          .where('isPaired', isEqualTo: true)
                          .snapshots(),
                      builder: (context, taskSnapshot) {
                        if (taskSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const ListTile(
                            title: Text("Loading..."),
                            subtitle: Text("Pending: 0, Completed: 0"),
                          );
                        }
                        if (taskSnapshot.hasError) {
                          return Center(
                            child: Text('Error: ${taskSnapshot.error}'),
                          );
                        }
                        if (!taskSnapshot.hasData ||
                            taskSnapshot.data!.docs.isEmpty) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(partnerId)
                                .get(),
                            builder: (context, partnerSnapshot) {
                              if (!partnerSnapshot.hasData ||
                                  !partnerSnapshot.data!.exists) {
                                return const ListTile(
                                  title: Text("Loading Partner..."),
                                );
                              }
                              final partnerData =
                                  partnerSnapshot.data!.data()
                                      as Map<String, dynamic>?;
                              final partnerName =
                                  partnerData?['name'] ?? 'Partner';
                              final initials = partnerName.isNotEmpty
                                  ? partnerName.substring(0, 1).toUpperCase()
                                  : '?';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color,
                                  foregroundColor: Colors.white,
                                  child: Text(initials),
                                ),
                                title: Text(partnerName),
                                subtitle: const Text(
                                  "Pending: 0, Completed: 0",
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PartnerTaskScreen(
                                        partnerId: partnerId,
                                        partnerName: partnerName,
                                      ),
                                    ),
                                  );
                                },
                                onLongPress: () => _unpairPartner(
                                  context,
                                  partnerId,
                                  partnerName,
                                ),
                              );
                            },
                          );
                        }

                        final tasks = taskSnapshot.data!.docs;
                        final totalTasks = tasks.length;
                        final completedTasks = tasks
                            .where(
                              (doc) =>
                                  doc['status']?[currentUser.uid] ==
                                  'completed',
                            )
                            .length;
                        final pendingTasks = totalTasks - completedTasks;

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .doc(partnerId)
                              .get(),
                          builder: (context, partnerSnapshot) {
                            if (!partnerSnapshot.hasData ||
                                !partnerSnapshot.data!.exists) {
                              return const ListTile(
                                title: Text("Loading Partner..."),
                              );
                            }
                            final partnerData =
                                partnerSnapshot.data!.data()
                                    as Map<String, dynamic>?;
                            final partnerName =
                                partnerData?['name'] ?? 'Partner';
                            final initials = partnerName.isNotEmpty
                                ? partnerName.substring(0, 1).toUpperCase()
                                : '?';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                child: Text(initials),
                              ),
                              title: Text(partnerName),
                              subtitle: Text(
                                "Pending: $pendingTasks, Completed: $completedTasks",
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PartnerTaskScreen(
                                      partnerId: partnerId,
                                      partnerName: partnerName,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () => _unpairPartner(
                                context,
                                partnerId,
                                partnerName,
                              ),
                            );
                          },
                        );
                      },
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
          // The logic to navigate to a new screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPartnerScreen()),
          );
        },
        backgroundColor: const Color.fromARGB(246, 202, 213, 241),
        foregroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
