import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'add_partner.dart';
import 'notifications.dart';
import 'partner_task.dart';
import '../themes/theme.dart';

class PartnerListScreen extends StatelessWidget {
  const PartnerListScreen({super.key});

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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.data() == null) {
                return IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_outlined),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;

              final bool notificationsEnabled =
                  userData['pushNotificationsEnabled'] ?? true;
              final int unreadCount = userData['unreadNotifications'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                  icon: notificationsEnabled && unreadCount > 0
                      ? badges.Badge(
                          badgeContent: Text(
                            '$unreadCount',
                            style: const TextStyle(color: Colors.white),
                          ),
                          badgeStyle: const badges.BadgeStyle(
                            badgeColor: Colors.red,
                          ),
                          child: const Icon(Icons.notifications_outlined),
                        )
                      : const Icon(Icons.notifications_outlined),
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
