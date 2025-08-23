// settings.dart
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _pushNotificationsEnabled = true;
  bool _isLoadingSettings = true;

  final TextEditingController _deleteConfirmationController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          _pushNotificationsEnabled =
              userDoc.data()!['pushNotificationsEnabled'] ?? false;
        });
      }
    }
    setState(() => _isLoadingSettings = false);
  }

  Future<void> _updateNotificationSetting(bool value) async {
    setState(() {
      _pushNotificationsEnabled = value;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pushNotificationsEnabled': value,
      }, SetOptions(merge: true));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? "Notifications turned on" : "Notifications turned off",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deleteConfirmationController.dispose();
    _passwordController.dispose();
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Password reset link sent to ${user.email}'),
              backgroundColor: const Color.fromARGB(
                255,
                184,
                155,
                218,
              ), // Optional: for success
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send password reset email: $e'),
              backgroundColor: Color.fromARGB(
                255,
                218,
                132,
                160,
              ), // Optional: for errors
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteUserAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      final userDocSnapshot = await db.collection('users').doc(user.uid).get();
      final userData = userDocSnapshot.data();

      if (userData != null) {
        final List<dynamic> partners = userData['partners'] ?? [];
        for (final partnerId in partners) {
          final partnerRef = db.collection('users').doc(partnerId);

          batch.update(partnerRef, {
            'partners': FieldValue.arrayRemove([user.uid]),
          });

          final notificationsQuery = await partnerRef
              .collection('notifications')
              .where('senderId', isEqualTo: user.uid)
              .get();
          for (final doc in notificationsQuery.docs) {
            batch.delete(doc.reference);
          }
        }
        final tasksQuery = await db
            .collection('tasks')
            .where('participants', arrayContains: user.uid)
            .get();
        for (final doc in tasksQuery.docs) {
          batch.delete(doc.reference);
        }

        final booksQuery = await db
            .collection('books')
            .where('userId', isEqualTo: user.uid)
            .get();
        for (final doc in booksQuery.docs) {
          batch.delete(doc.reference);
        }
      }

      batch.delete(db.collection('users').doc(user.uid));

      await batch.commit();

      await user.delete();

      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account deleted successfully.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "An error occurred.")),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred: $e")),
        );
      }
    }
  }

  void _showPasswordConfirmationDialog() {
    _passwordController.clear();
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppTheme.primaryColor),
        ),
        child: AlertDialog(
          title: const Text('Enter Your Password'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final password = _passwordController.text;
                Navigator.of(context).pop();
                _deleteUserAccount(password);
              },
              child: const Text('Confirm & Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    _deleteConfirmationController.clear();
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: AppTheme.primaryColor),
        ),
        child: AlertDialog(
          title: const Text(
            'Delete Account?',
            style: TextStyle(color: Colors.red),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This action is permanent and cannot be undone. All your tasks, partnerships, and data will be erased.",
              ),
              const SizedBox(height: 20),
              const Text('To confirm, please type "DELETE" below:'),
              TextField(
                controller: _deleteConfirmationController,
                decoration: const InputDecoration(hintText: 'DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _deleteConfirmationController,
              builder: (context, value, child) {
                return TextButton(
                  onPressed: value.text == 'DELETE'
                      ? () {
                          Navigator.of(context).pop();
                          _showPasswordConfirmationDialog();
                        }
                      : null,
                  child: const Text(
                    'Next',
                    style: TextStyle(color: Color.fromARGB(255, 218, 132, 160)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
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
                final newName = _nameController.text.trim();

                if (newName.isEmpty) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Invalid Name'),
                      content: const Text('Name cannot be empty.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
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
        title: const Text('About PairUp'),
        content: const SingleChildScrollView(
          child: Text('''

Version: 1.0.2

PairUp is a collaborative productivity app that helps you and your partner achieve goals together by turning accountability into a shared journey.

Key Features:

Shared Task Management: Create, track, and complete tasks as a team.

Collaborative Reading Lists: Discover books, track progress, and share notes.

Real-time Communication: Stay connected with dedicated chats and instant updates.

Personalized Analytics: View reports on tasks, books, and activity to track growth.
'''),
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
      body: _isLoadingSettings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
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
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Push Notifications'),
                  trailing: Switch(
                    value: _pushNotificationsEnabled,
                    onChanged: _updateNotificationSetting,
                    activeColor: AppTheme.primaryColor,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Reset Password'),
                  onTap: () => _sendPasswordResetEmail(user),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: Color.fromARGB(255, 218, 132, 160),
                  ),
                  title: const Text('Delete Account'),
                  onTap: _showDeleteAccountDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log Out'),
                  onTap: _signOut,
                ),
                const Divider(),
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
