import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../themes/theme.dart';

class EditTaskScreen extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;

  const EditTaskScreen({
    super.key,
    required this.taskId,
    required this.taskData,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final TextEditingController _taskNameController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late DateTime _selectedDay;
  late DateTime _focusedDay;
  bool _isLoading = false;

  late String _initialTaskName;
  late DateTime _initialSelectedDay;

  @override
  void initState() {
    super.initState();
    // Populate the fields with the existing task data
    _taskNameController.text = widget.taskData['title'] ?? '';
    _notesController.text = widget.taskData['notes'] ?? '';
    _selectedDay = (widget.taskData['dueDate'] as Timestamp).toDate();
    _focusedDay = _selectedDay;

    _initialTaskName = _taskNameController.text;
    _initialSelectedDay = _selectedDay;
  }

  @override
  void dispose() {
    _taskNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _updateTask() async {
    final taskName = _taskNameController.text.trim();
    if (taskName.isEmpty) {
      // Show warning if task name is empty
      return;
    }

    setState(() => _isLoading = true);

    final bool hasNameChanged = _initialTaskName != taskName;
    final bool hasDateChanged = !isSameDay(_initialSelectedDay, _selectedDay);
    final bool shouldSendNotification = hasNameChanged || hasDateChanged;

    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .update({
            'title': taskName,
            'dueDate': Timestamp.fromDate(_selectedDay),
            'notes': _notesController.text.trim(),
          });

      if (shouldSendNotification) {
        final currentUser = FirebaseAuth.instance.currentUser!;
        final currentUserName = currentUser.displayName ?? 'A User';
        final currentUserFirstName = currentUserName.split(' ').first;
        final partnerId = widget.taskData['participants'].firstWhere(
          (id) => id != currentUser.uid,
          orElse: () => null,
        );

        if (partnerId != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(partnerId)
              .collection('notifications')
              .add({
                'type': 'task_edited',
                'message':
                    '$currentUserFirstName edited the task: "$taskName".',
                'senderId': currentUser.uid,
                'senderName': currentUserName,
                'initials': currentUserFirstName.substring(0, 1),
                'timestamp': FieldValue.serverTimestamp(),
              });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(partnerId)
              .update({'unreadNotifications': FieldValue.increment(1)});
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Task updated successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to update task: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Task")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _taskNameController,
              decoration: InputDecoration(
                labelText: "Task Name",
                labelStyle: TextStyle(color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "Notes",
                hintText: "Add any extra details here...",
                labelStyle: TextStyle(color: AppTheme.primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateTask,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: AppTheme.textOnPrimary,
                backgroundColor: AppTheme.primaryColor,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
