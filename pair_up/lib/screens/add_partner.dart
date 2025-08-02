// add_partner.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import '../themes/theme.dart';

class AddPartnerScreen extends StatefulWidget {
  const AddPartnerScreen({super.key});

  @override
  State<AddPartnerScreen> createState() => _AddPartnerScreenState();
}

class _AddPartnerScreenState extends State<AddPartnerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  final currentUser = FirebaseAuth.instance.currentUser!;

  String _shareCodeValue = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _getOrCreateShareCode();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _getOrCreateShareCode() async {
    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection('users').doc(currentUser.uid).get();
    final userData = userDoc.data();

    if (userData != null && userData.containsKey('shareCode')) {
      setState(() {
        _shareCodeValue = userData['shareCode'] as String;
      });
    } else {
      final code = (Random().nextInt(900000) + 100000).toString();
      await db.collection('users').doc(currentUser.uid).update({
        'shareCode': code,
      });
      setState(() {
        _shareCodeValue = code;
      });
    }
  }

  Future<void> _sendPartnerRequest() async {
    final shortCode = _codeController.text.trim();
    if (shortCode.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Warning"),
            content: const Text("Please enter a partner code."),
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

    final db = FirebaseFirestore.instance;
    final querySnapshot = await db
        .collection('users')
        .where('shareCode', isEqualTo: shortCode)
        .get();

    if (querySnapshot.docs.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Invalid Code"),
            content: const Text("The partner code you entered is invalid."),
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

    final partnerId = querySnapshot.docs.first.id;
    if (partnerId == currentUser.uid) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error"),
            content: const Text("You cannot add yourself as a partner."),
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

    // Now send the request with the correct UID
    await db.collection('partner_requests').add({
      'senderId': currentUser.uid,
      'senderName': currentUser.displayName ?? 'A New User',
      'receiverId': partnerId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Request Sent"),
          content: const Text("Your partner request has been sent."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _shareCode() async {
    if (_shareCodeValue.isEmpty) return;
    const deepLinkUrl = 'https://yourdomain.com/invite';
    final shareText = "$deepLinkUrl?code=$_shareCodeValue";
    await Share.share(shareText, subject: "Pair-Up Invite");
  }

  @override
  Widget build(BuildContext context) {
    const deepLinkUrl = 'https://yourdomain.com/invite';
    final qrData = "$deepLinkUrl?code=$_shareCodeValue";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Partner"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: "Share Code"),
            Tab(text: "Enter Code"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // "Share Code" Tab
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Your PairUp Code",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 150.0,
                  ),
                  /*const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _shareCodeValue,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),*/
                  const SizedBox(height: 20),
                  Text(
                    "If QR scan doesn't work, use this: ",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: _shareCodeValue.isEmpty ? null : _shareCode,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppTheme.primaryColor,
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text("Share My Code"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // "Enter Code" Tab
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Enter the code from your partner.",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: "Partner's Code",
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
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendPartnerRequest,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Send Request"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
