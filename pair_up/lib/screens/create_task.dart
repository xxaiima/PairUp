// create_task_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../themes/theme.dart';

class CreateTaskScreen extends StatefulWidget {
  final String partnerName;
  final String partnerId;

  const CreateTaskScreen({
    super.key,
    required this.partnerName,
    required this.partnerId,
  });

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TextEditingController _taskNameController = TextEditingController();
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _isLoading = false;

  Future<void> _createTask() async {
    final taskName = _taskNameController.text.trim();
    if (taskName.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Warning"),
            content: const Text("Please enter a task name."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser!;
    final participants = [currentUser.uid, widget.partnerId]..sort();
    final participantString = participants.join(',');
    final status = {currentUser.uid: 'pending', widget.partnerId: 'pending'};

    try {
      await FirebaseFirestore.instance.collection('tasks').add({
        'title': taskName,
        'dueDate': Timestamp.fromDate(_selectedDay),
        'createdBy': currentUser.uid,
        'participants': participants,
        'participantString': participantString,
        'isPaired': true,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to create task: $e")));
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
      appBar: AppBar(title: Text("New Task")),
      body: Padding(
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
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _createTask,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryColor,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}
