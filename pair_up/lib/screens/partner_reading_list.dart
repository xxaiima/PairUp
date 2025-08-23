import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'book_details.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class PartnerReadingListScreen extends StatelessWidget {
  final String partnerId;
  final String partnerName;

  const PartnerReadingListScreen({
    super.key,
    required this.partnerId,
    required this.partnerName,
  });

  /*Future<void> _recommendBook(BuildContext context, String bookTitle) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final currentUserName = currentUser.displayName?.split(' ').first ?? 'You';

    // Send a new notification to the partner
    await FirebaseFirestore.instance
        .collection('users')
        .doc(partnerId)
        .collection('notifications')
        .add({
          'senderId': currentUser.uid,
          'type': 'book_recommended',
          'message': '$currentUserName recommends the book: "$bookTitle".',
          'initials': currentUserName.substring(0, 1),
          'senderName': currentUser.displayName ?? 'Anonymous',
          'timestamp': FieldValue.serverTimestamp(),
        });

    await FirebaseFirestore.instance.collection('users').doc(partnerId).update({
      'unreadNotifications': FieldValue.increment(1),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recommended "$bookTitle" to $partnerName.')),
      );
    }
  }*/

  Widget _buildBookCover(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.book, size: 50, color: Colors.grey),
      );
    }

    final secureUrl = imageUrl.replaceFirst('http://', 'https://');

    return Image.network(
      secureUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.book, size: 50, color: Colors.grey),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Books"),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('books')
                  .where('userId', isEqualTo: partnerId)
                  .where('isShared', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      '${partnerName} has not shared any books yet.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final books = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(16.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 16.0,
                    childAspectRatio: 0.5,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    final bookData =
                        books[index].data() as Map<String, dynamic>;
                    final String bookId = books[index].id;
                    final imageUrl = bookData['imageUrl'] ?? '';
                    final bookTitle = bookData['title'] ?? 'No Title';
                    final bookAuthor = bookData['author'] ?? 'Unknown Author';
                    final double rating = (bookData['rating'] ?? 0).toDouble();

                    final int currentPage = bookData['currentPage'] ?? 0;
                    final int totalPages = bookData['totalPages'] ?? 0;
                    final double progress = totalPages > 0
                        ? currentPage / totalPages
                        : 0.0;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookDetailsScreen(
                              bookId: bookId,
                              bookData: bookData,
                              isReadOnly: true,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _buildBookCover(imageUrl)),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    bookTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    'by $bookAuthor',
                                    style: const TextStyle(color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    color: Theme.of(context).primaryColor,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.2),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    '$currentPage / $totalPages pages',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: RatingBarIndicator(
                                    rating: rating,
                                    itemBuilder: (context, index) => const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                    ),
                                    itemCount: 5,
                                    itemSize: 16.0,
                                    direction: Axis.horizontal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
