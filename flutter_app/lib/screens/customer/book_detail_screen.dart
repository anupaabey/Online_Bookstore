import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';

/// Shows full details (title, author, price, description) and lets the
/// customer choose a quantity and add the book to their cart.
class BookDetailScreen extends StatefulWidget {
  final int bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Book? _book;
  bool _loading = true;
  String? _error;
  int _quantity = 1;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.get('books.php?id=${widget.bookId}');
      setState(() => _book = Book.fromJson(data));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not load this book.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    try {
      await context.read<CartProvider>().addToCart(_book!.id, quantity: _quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${_book!.title} to cart.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add to cart. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_book?.title ?? 'Book Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final book = _book!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              height: 160,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded, size: 56, color: Colors.indigo),
            ),
          ),
          const SizedBox(height: 20),
          Text(book.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('by ${book.author}', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('\$${book.price.toStringAsFixed(2)}')),
              if (book.categoryName != null) Chip(label: Text(book.categoryName!)),
              Chip(
                label: Text(book.inStock ? '${book.stockQty} in stock' : 'Out of stock'),
                backgroundColor: book.inStock ? Colors.green.shade50 : Colors.red.shade50,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            book.description.isEmpty ? 'No description available.' : book.description,
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 28),
          if (book.inStock) ...[
            Row(
              children: [
                const Text('Quantity:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_quantity', style: const TextStyle(fontSize: 16)),
                IconButton(
                  onPressed: _quantity < book.stockQty ? () => setState(() => _quantity++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _adding ? null : _addToCart,
                icon: _adding
                    ? const SizedBox(
                        height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Cart'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ] else
            const Text('This book is currently out of stock.', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
