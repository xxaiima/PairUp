// NotificationsScreen.dart
import 'package:flutter/material.dart';
import '../themes/theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  final List<Map<String, String>> _notifications = const [
    {
      'initials': 'A',
      'message': 'Alex completed "Finish weekly report." Your turn!',
      'time': '2h ago',
    },
    {
      'initials': 'B',
      'message': 'Ben just added a new task: "Book flight."',
      'time': 'Yesterday',
    },
    {
      'initials': 'C',
      'message': 'You have a new partner request from Chris Lee.',
      'time': '3d ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    child: Text(notification['initials']!),
                  ),
                  title: Text(
                    notification['message']!,
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                  subtitle: Text(
                    notification['time']!,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  onTap: () {
                    // TODO: Handle notification tap
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}
