// books_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../themes/theme.dart';
import 'book_details.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _isDeleting = false;
  final List<String> _selectedBookIds = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchBooks(_searchController.text, loadMore: false);
  }

  Future<void> _searchBooks(String query, {bool loadMore = false}) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    if (!loadMore) {
      setState(() {
        _searchResults = [];
      });
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/books/v1/volumes?q=$query'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data['items'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load books');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addBookToReadingList(Map<String, dynamic> book) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final volumeInfo = book['volumeInfo'];
    final title = volumeInfo['title'];
    final authors = volumeInfo['authors']?.join(', ') ?? 'Unknown Author';
    final pageCount = volumeInfo['pageCount'] ?? 0;
    final imageUrl = volumeInfo['imageLinks']?['thumbnail'] ?? '';

    await FirebaseFirestore.instance.collection('books').add({
      'userId': currentUser.uid,
      'title': title,
      'author': authors,
      'imageUrl': imageUrl,
      'currentPage': 0,
      'totalPages': pageCount,
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Book Added'),
          content: Text('$title has been added to your reading list.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _searchController.clear();
                FocusScope.of(context).unfocus();
              },
              child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteSelectedBooks() async {
    final db = FirebaseFirestore.instance;
    await Future.wait(
      _selectedBookIds.map(
        (bookId) => db.collection('books').doc(bookId).delete(),
      ),
    );

    if (mounted) {
      // Replaced SnackBar with a dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deletion Complete'),
          content: const Text('Books deleted successfully.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );
      setState(() {
        _selectedBookIds.clear();
        _isDeleting = false;
      });
    }
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'Search for a book to see results.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index]['volumeInfo'];
        final title = book['title'] ?? 'No Title';
        final authors = book['authors']?.join(', ') ?? 'Unknown Author';
        final imageUrl = book['imageLinks']?['thumbnail'] ?? '';
        return ListTile(
          leading: imageUrl.isNotEmpty
              ? Image.network(imageUrl, width: 50, fit: BoxFit.cover)
              : null,
          title: Text(title),
          subtitle: Text(authors),
          onTap: () => _addBookToReadingList(_searchResults[index]),
        );
      },
    );
  }

  Widget _buildReadingList() {
    final currentUser = FirebaseAuth.instance.currentUser!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('books')
          .where('userId', isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No books added yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final books = snapshot.data!.docs;

        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            final bookData = books[index].data() as Map<String, dynamic>;
            final String bookTitle = bookData['title'] ?? 'No Title';
            final String bookAuthor = bookData['author'] ?? 'Unknown Author';
            final String imageUrl = bookData['imageUrl'] ?? '';
            final String bookId = books[index].id;

            return ListTile(
              leading: _isDeleting
                  ? Checkbox(
                      value: _selectedBookIds.contains(bookId),
                      activeColor: AppTheme.primaryColor,
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedBookIds.add(bookId);
                          } else {
                            _selectedBookIds.remove(bookId);
                          }
                        });
                      },
                    )
                  : imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: 50, fit: BoxFit.cover)
                  : null,
              title: Text(bookTitle),
              subtitle: Text('by $bookAuthor'),
              trailing: _isDeleting
                  ? null
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isDeleting
                  ? () {
                      setState(() {
                        if (_selectedBookIds.contains(bookId)) {
                          _selectedBookIds.remove(bookId);
                        } else {
                          _selectedBookIds.add(bookId);
                        }
                      });
                    }
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookDetailsScreen(
                            bookId: bookId,
                            bookData: bookData,
                          ),
                        ),
                      );
                    },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          cursorColor: AppTheme.primaryColor,
          decoration: InputDecoration(
            hintText: 'Search for books...',
            hintStyle: TextStyle(color: AppTheme.primaryColor.withOpacity(0.5)),
            prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          style: TextStyle(color: AppTheme.primaryColor),
        ),
        automaticallyImplyLeading: false,
        actions: _searchController.text.isNotEmpty
            ? null
            : _isDeleting
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    if (_selectedBookIds.isNotEmpty) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Books?'),
                          content: Text(
                            'Are you sure you want to delete ${_selectedBookIds.length} books?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Color(0xFF0A2342)),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _deleteSelectedBooks();
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      setState(() => _isDeleting = false);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isDeleting = false;
                      _selectedBookIds.clear();
                    });
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () {
                    setState(() => _isDeleting = true);
                  },
                ),
              ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildReadingList(),
          ),
        ],
      ),
    );
  }
}
