import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../authentication/welcome.dart';
import '../themes/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _pushNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _sendPasswordResetEmail(User? user) async {
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Password Reset'),
              content: Text('Password reset link sent to ${user.email}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to send password reset email: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _showEditProfileDialog(User? user) {
    _nameController.text = user?.displayName ?? '';
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppTheme.primaryColor),
        ),
        child: AlertDialog(
          title: const Text('Edit Profile'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await user?.updateDisplayName(_nameController.text);
                if (context.mounted) {
                  setState(() {});
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Profile Updated'),
                      content: const Text('Your profile has been updated.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App Version: 1.0.0'),
            const SizedBox(height: 10),
            const Text(
              'User Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Getting Started:'),
            const Text('• Share your unique code to connect with a partner.'),
            const Text(
              '• Accept or decline partner requests from the notifications screen.',
            ),
            const SizedBox(height: 8),
            const Text('Task Management:'),
            const Text(
              '• Create and manage tasks for a partnership from the partner\'s screen.',
            ),
            const Text(
              '• Check off tasks to mark them complete or use the delete button.',
            ),
            const SizedBox(height: 8),
            const Text('Book Management:'),
            const Text('• Use the search bar to find and add new books.'),
            const Text('• Tap a book to update progress, notes, or ratings.'),
            const Text(
              '• Use the sharing toggle to share your progress with partners.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String userInitials = user?.displayName?.isNotEmpty == true
        ? user!.displayName!.substring(0, 1).toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primaryColor,
                    child: Text(
                      userInitials,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'No Name',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'No Email',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditProfileDialog(user),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          // Notifications Section
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Push Notifications'),
            trailing: Switch(
              value: _pushNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _pushNotificationsEnabled = value;
                });
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
          const Divider(),
          // Account Management
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Reset Password'),
            onTap: () => _sendPasswordResetEmail(user),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out'),
            onTap: _signOut,
          ),
          const Divider(),
          // About Section
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: _showAboutDialog,
          ),
          const Divider(),
        ],
      ),
    );
  }
}
