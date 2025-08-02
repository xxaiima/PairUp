import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../themes/theme.dart';

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
  double _rating = 0;
  bool _isShared = false;
  bool _isLoading = false;

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
  }

  @override
  void dispose() {
    _notesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    await FirebaseFirestore.instance
        .collection('books')
        .doc(widget.bookId)
        .update({
          'notes': _notesController.text,
          'rating': _rating,
          'isShared': _isShared,
        });

    if (mounted) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Changes Saved"),
          content: const Text("Your changes have been saved."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final title = widget.bookData['title'] ?? 'No Title';
    final author = widget.bookData['author'] ?? 'Unknown Author';
    final imageUrl = widget.bookData['imageUrl'] ?? '';
    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Hide the save button if the screen is read-only
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: 150, fit: BoxFit.cover)
                  : const Icon(Icons.book, size: 150, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text('by $author', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            // Page Count Section
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
                        backgroundColor: Color.fromARGB(246, 202, 213, 241),
                      ),
                    ],
                  ),
                ),
                // Hide the edit button if the screen is read-only
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
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: Colors.amber),
              // The onRatingUpdate handler is now always active
              onRatingUpdate: (rating) {
                setState(() => _rating = rating);
              },
            ),
            const SizedBox(height: 24),
            Text('Notes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 5,
              readOnly: widget.isReadOnly, // Make the text field read-only
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
                hintText: 'Add your notes here...',
              ),
            ),
            const SizedBox(height: 24),
            // Hide the sharing option if the screen is read-only
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
                    onChanged: (value) {
                      setState(() => _isShared = value);
                    },
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
