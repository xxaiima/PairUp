import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../themes/theme.dart';
import 'dart:async';

class BookDetailsScreen extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic> bookData;
  final bool isReadOnly;

  const BookDetailsScreen({
    super.key,
    required this.bookId,
    required this.bookData,
    this.isReadOnly = false,
  });

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  Timer? _notesDebounce;
  double _rating = 0;
  bool _isShared = false;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.bookData['notes'] ?? '';
    _rating = (widget.bookData['rating'] ?? 0).toDouble();
    _isShared = widget.bookData['isShared'] ?? false;
    _currentPage = widget.bookData['currentPage'] ?? 0;
    _totalPages = widget.bookData['totalPages'] ?? 0;

    _notesController.addListener(_onNotesChanged);
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _notesController.dispose();
    _pageController.dispose();
    _notesDebounce?.cancel();
    super.dispose();
  }

  void _onNotesChanged() {
    if (_notesDebounce?.isActive ?? false) _notesDebounce!.cancel();
    _notesDebounce = Timer(const Duration(seconds: 1), () {
      FirebaseFirestore.instance.collection('books').doc(widget.bookId).update({
        'notes': _notesController.text,
      });
    });
  }

  Future<void> _updateRating(double newRating) async {
    setState(() => _rating = newRating);
    await FirebaseFirestore.instance
        .collection('books')
        .doc(widget.bookId)
        .update({'rating': newRating});
  }

  Future<void> _updateSharing(bool isShared) async {
    setState(() => _isShared = isShared);
    await FirebaseFirestore.instance
        .collection('books')
        .doc(widget.bookId)
        .update({'isShared': isShared});
  }

  Future<void> _updateReadingProgress() async {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Update Progress for '${widget.bookData['title']}'"),
          content: TextField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            cursorColor: AppTheme.primaryColor,
            decoration: InputDecoration(
              hintText: "Enter current page (out of $_totalPages)",
              hintStyle: TextStyle(color: AppTheme.primaryColor),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
            TextButton(
              onPressed: () {
                final int? newPage = int.tryParse(_pageController.text);
                if (newPage != null && newPage >= 0 && newPage <= _totalPages) {
                  FirebaseFirestore.instance
                      .collection('books')
                      .doc(widget.bookId)
                      .update({'currentPage': newPage});
                  setState(() => _currentPage = newPage);
                  Navigator.of(context).pop();
                } else {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Invalid Input'),
                      content: Text(
                        "Please enter a valid page number between 0 and $_totalPages.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'OK',
                            style: TextStyle(color: AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: Text(
                'Update',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
      );
    }
  }

  String _secureImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.replaceFirst('http://', 'https://');
  }

  Widget _buildBookCover(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.book, size: 150, color: Colors.grey);
    }
    // Ensure the URL uses https for web compatibility.
    final secureUrl = _secureImageUrl(url);

    return Image.network(
      secureUrl,
      height: 200,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.book, size: 150, color: Colors.grey);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.bookData['title'] ?? 'No Title';
    final author = widget.bookData['author'] ?? 'Unknown Author';
    final imageUrl = widget.bookData['imageUrl'];
    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildBookCover(imageUrl)),
            const SizedBox(height: 16),
            Text('by $author', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progress',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text("$_currentPage / $_totalPages pages"),
                      LinearProgressIndicator(
                        value: progress,
                        color: AppTheme.primaryColor,
                        backgroundColor: const Color.fromARGB(
                          246,
                          202,
                          213,
                          241,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _updateReadingProgress,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Rating', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: widget.isReadOnly,
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) =>
                    const Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: _updateRating,
              ),
            ),
            const SizedBox(height: 24),
            Text('Notes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 5,
              readOnly: widget.isReadOnly,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                hintText: 'Add your notes here...',
              ),
            ),
            const SizedBox(height: 24),
            if (!widget.isReadOnly)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Share with Partners',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  Switch(
                    value: _isShared,
                    onChanged: _updateSharing,
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
