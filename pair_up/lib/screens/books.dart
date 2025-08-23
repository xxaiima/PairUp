// books_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
  Timer? _debounce;

  int _startIndex = 0;
  final int _maxResults = 20;
  bool _canLoadMore = false;
  bool _isLoadingMore = false;

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text;

      setState(() {
        _isSearching = query.isNotEmpty;
      });

      if (query.isNotEmpty) {
        _startIndex = 0;
        _searchBooks(query, loadMore: false);
      }
    });
  }

  Future<void> _searchBooks(String query, {bool loadMore = false}) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _canLoadMore = false;
      });
      return;
    }

    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _searchResults = [];
        _startIndex = 0;
      });
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/books/v1/volumes?q=$query&maxResults=$_maxResults&startIndex=$_startIndex',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>? ?? [];

        if (mounted) {
          setState(() {
            if (loadMore) {
              _searchResults.addAll(items);
            } else {
              _searchResults = items;
            }
            _startIndex += items.length;

            _canLoadMore = items.length == _maxResults;

            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        throw Exception('Failed to load books');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _addBookToReadingList(Map<String, dynamic> book) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final volumeInfo = book['volumeInfo'];
    final title = volumeInfo['title'];
    final authors = volumeInfo['authors']?.join(', ') ?? 'Unknown Author';
    final pageCount = volumeInfo['pageCount'] ?? 0;
    final imageUrl = _secureImageUrl(volumeInfo['imageLinks']?['thumbnail']);

    await FirebaseFirestore.instance.collection('books').add({
      'userId': currentUser.uid,
      'title': title,
      'author': authors,
      'imageUrl': imageUrl,
      'currentPage': 0,
      'totalPages': pageCount,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title has been added to your reading list.')),
      );
      _searchController.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _searchResults = [];
      });
    }
  }

  Future<void> _deleteSelectedBooks() async {
    if (_selectedBookIds.isEmpty) return;

    final int numberOfBooksToDelete = _selectedBookIds.length;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    for (final bookId in _selectedBookIds) {
      batch.delete(db.collection('books').doc(bookId));
    }

    await batch.commit();

    if (mounted) {
      setState(() {
        _selectedBookIds.clear();
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$numberOfBooksToDelete book(s) deleted successfully.'),
          backgroundColor: const Color.fromARGB(255, 184, 155, 218),
        ),
      );
    }
  }

  Widget _buildBookImage(String? url) {
    if (url == null || url.isEmpty) {
      return const Icon(Icons.book, size: 40, color: Colors.grey);
    }
    final secureUrl = url.replaceFirst('http://', 'https://');

    return Image.network(
      secureUrl,
      width: 40,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.book, size: 40, color: Colors.grey);
      },
    );
  }

  String _secureImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.replaceFirst('http://', 'https://');
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
    return ListView.separated(
      itemCount: _searchResults.length + 1,
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          if (_isLoadingMore) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (_canLoadMore) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _searchBooks(_searchController.text, loadMore: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load More'),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        final book = _searchResults[index]['volumeInfo'];
        final title = book['title'] ?? 'No Title';
        final authors = book['authors']?.join(', ') ?? 'Unknown Author';
        final imageUrl = book['imageLinks']?['thumbnail'] ?? '';

        return ListTile(
          leading: _buildBookImage(imageUrl),
          title: Text(title),
          subtitle: Text(authors),
          onTap: () => _addBookToReadingList(_searchResults[index]),
        );
      },
      separatorBuilder: (context, index) => const Divider(),
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
              'Your reading list is empty.\nSearch for a book to get started!',
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
                      checkColor: AppTheme.textOnPrimary,
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
                  : _buildBookImage(imageUrl),
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
            suffixIcon: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    color: AppTheme.primaryColor,
                    onPressed: () {
                      _searchController.clear();
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AppTheme.textOnPrimary,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          style: TextStyle(color: AppTheme.primaryColor),
        ),
        automaticallyImplyLeading: false,
        actions: _isSearching
            ? []
            : _isDeleting
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedBookIds.isNotEmpty
                      ? () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Books?'),
                              content: Text(
                                'Are you sure you want to delete ${_selectedBookIds.length} book(s)? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _deleteSelectedBooks();
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 218, 132, 160),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
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
            child: _isSearching ? _buildSearchResults() : _buildReadingList(),
          ),
        ],
      ),
    );
  }
}
