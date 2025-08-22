// report_generation_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../themes/theme.dart';
import 'dart:async';

class ReportGenerationScreen extends StatefulWidget {
  const ReportGenerationScreen({super.key});

  @override
  State<ReportGenerationScreen> createState() => _ReportGenerationScreenState();
}

class _ReportGenerationScreenState extends State<ReportGenerationScreen> {
  final _db = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser!;
  Map<String, dynamic> _reportData = {};
  String _selectedDateRange = 'All Time';

  late Future<void> _reportDataFuture;

  @override
  void initState() {
    super.initState();
    _reportDataFuture = _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedDateRange) {
      case 'Last 7 Days':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Last 30 Days':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case 'Last 365 Days':
        startDate = now.subtract(const Duration(days: 365));
        break;
      default:
        startDate = DateTime.fromMillisecondsSinceEpoch(0);
        break;
    }

    try {
      // Get the current user's partners for the number of pairs metric
      final currentUserDoc = await _db
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final partners =
          (currentUserDoc.data()?['partners'] as List<dynamic>?) ?? [];
      final myTotalPairs = partners.length;

      // 1. Task Metrics
      final tasksSnapshot = await _db
          .collection('tasks')
          .where('participants', arrayContains: currentUser.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .get();

      final allTasksForUser = tasksSnapshot.docs.length;
      final myTasksCreated = tasksSnapshot.docs
          .where((doc) => doc.data()['createdBy'] == currentUser.uid)
          .length;
      final myTasksCompleted = tasksSnapshot.docs.where((doc) {
        final status = (doc.data()['status'] as Map<String, dynamic>);
        return status[currentUser.uid] == 'completed';
      }).length;
      final myTasksOverdue = tasksSnapshot.docs.where((doc) {
        final status = (doc.data()['status'] as Map<String, dynamic>);
        final dueDate = (doc.data()['dueDate'] as Timestamp).toDate();
        return dueDate.isBefore(now) && status[currentUser.uid] != 'completed';
      }).length;
      final myTasksDue = allTasksForUser - myTasksCompleted - myTasksOverdue;
      final myCompletionRate = allTasksForUser > 0
          ? (myTasksCompleted / allTasksForUser) * 100
          : 0.0;

      int myTasksDeleted = 0;
      if (partners.isNotEmpty) {
        final partnersNotificationsSnapshot = await _db
            .collection('users')
            .doc(partners.first)
            .collection('notifications')
            .where('senderId', isEqualTo: currentUser.uid)
            .where('type', isEqualTo: 'task_deleted')
            .get();
        myTasksDeleted = partnersNotificationsSnapshot.docs.length;
      }

      // 2. Communication Metrics
      int myMessagesSent = 0;
      final chatsSnapshot = await _db.collection('chats').get();
      for (var chatDoc in chatsSnapshot.docs) {
        if ((chatDoc.data()['participants'] as List).contains(
          currentUser.uid,
        )) {
          final messagesSnapshot = await chatDoc.reference
              .collection('messages')
              .where('senderId', isEqualTo: currentUser.uid)
              .where('timestamp', isGreaterThanOrEqualTo: startDate)
              .get();
          myMessagesSent += messagesSnapshot.docs.length;
        }
      }

      // 3. Book MetricS
      final myBooksSnapshot = await _db
          .collection('books')
          .where('userId', isEqualTo: currentUser.uid)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .get();
      final myBooksAdded = myBooksSnapshot.docs.length;
      int myBooksRead = 0;
      double myTotalPagesRead = 0;
      double myTotalRating = 0;

      for (var bookDoc in myBooksSnapshot.docs) {
        final bookData = bookDoc.data();
        final totalPages = bookData['totalPages'] as int? ?? 0;
        final currentPage = bookData['currentPage'] as int? ?? 0;
        final rating = (bookData['rating'] as double?) ?? 0.0;

        // NEW LOGIC: Total Pages Read is the sum of all current pages
        myTotalPagesRead += currentPage;

        // NEW LOGIC: Books I have read is when currentPage == totalPages
        if (totalPages > 0 && currentPage == totalPages) {
          myBooksRead++;
        }

        myTotalRating += rating;
      }
      final myAvgRating = myBooksAdded > 0 ? myTotalRating / myBooksAdded : 0.0;

      setState(() {
        _reportData = {
          'myTotalPairs': myTotalPairs,
          'myTasksCreated': myTasksCreated,
          'myTasksCompleted': myTasksCompleted,
          'myTasksDeleted': myTasksDeleted,
          'myTasksDue': myTasksDue,
          'myTasksOverdue': myTasksOverdue,
          'myCompletionRate': myCompletionRate,
          'myMessagesSent': myMessagesSent,
          'myBooksAdded': myBooksAdded,
          'myBooksRead': myBooksRead,
          'myTotalPagesRead': myTotalPagesRead,
          'myAvgRating': myAvgRating,
        };
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load report data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your PairUp Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _reportDataFuture = _fetchReportData();
              });
            },
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: FutureBuilder(
        future: _reportDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Report for:',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    DropdownButton<String>(
                      value: _selectedDateRange,
                      items:
                          [
                            'All Time',
                            'Last 7 Days',
                            'Last 30 Days',
                            'Last 365 Days',
                          ].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedDateRange = newValue;
                            _reportDataFuture = _fetchReportData();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text('Tasks', style: Theme.of(context).textTheme.headlineSmall),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.group_outlined, color: Colors.blue),
                  title: const Text('My Total Pairs'),
                  trailing: Text(
                    _reportData['myTotalPairs']?.toString() ?? '0',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(
                    Icons.playlist_add_check,
                    color: AppTheme.primaryColor,
                  ),
                  title: const Text('Tasks I Created'),
                  trailing: Text(
                    _reportData['myTasksCreated']?.toString() ?? '0',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  title: const Text('Tasks I Completed'),
                  trailing: Text(
                    _reportData['myTasksCompleted']?.toString() ?? '0',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Tasks I Deleted'),
                  trailing: Text(
                    _reportData['myTasksDeleted']?.toString() ?? '0',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.watch_later_outlined,
                    color: Colors.grey,
                  ),
                  title: const Text('Tasks Currently Due'),
                  trailing: Text(_reportData['myTasksDue']?.toString() ?? '0'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.timer_off_outlined,
                    color: Colors.red,
                  ),
                  title: const Text('Overdue Tasks'),
                  trailing: Text(
                    _reportData['myTasksOverdue']?.toString() ?? '0',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.green),
                  title: const Text('My Completion Rate'),
                  trailing: Text(
                    '${_reportData['myCompletionRate']?.toStringAsFixed(1) ?? '0.0'}%',
                  ),
                ),
                const Divider(),

                const SizedBox(height: 30),
                Text('Books', style: Theme.of(context).textTheme.headlineSmall),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.book_outlined, color: Colors.brown),
                  title: const Text('Books I Added'),
                  trailing: Text(
                    _reportData['myBooksAdded']?.toString() ?? '0',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.book_rounded, color: Colors.amber),
                  title: const Text('Books I Have Read'),
                  trailing: Text(_reportData['myBooksRead']?.toString() ?? '0'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.bookmark_added_outlined,
                    color: Colors.brown,
                  ),
                  title: const Text('Total Pages Read'),
                  trailing: Text(
                    _reportData['myTotalPagesRead']?.toStringAsFixed(0) ?? '0',
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.star, color: Colors.amber),
                  title: const Text('Average Book Rating'),
                  trailing: Text(
                    '${_reportData['myAvgRating']?.toStringAsFixed(1) ?? '0.0'}',
                  ),
                ),
                const Divider(),

                const SizedBox(height: 30),
                Text(
                  'Communication',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.message_outlined,
                    color: Colors.lightBlue,
                  ),
                  title: const Text('Messages I Shared'),
                  trailing: Text(
                    _reportData['myMessagesSent']?.toString() ?? '0',
                  ),
                ),
                const Divider(),
              ],
            ),
          );
        },
      ),
    );
  }
}
