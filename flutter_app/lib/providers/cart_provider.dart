import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../services/api_service.dart';

/// Keeps the customer's cart in memory and mirrors every change to the
/// backend so the cart survives app restarts (server is the source of truth).
class CartProvider extends ChangeNotifier {
  List<CartItem> _items = [];
  double _total = 0.0;
  bool _loading = false;

  List<CartItem> get items => _items;
  double get total => _total;
  bool get isLoading => _loading;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  Future<void> fetchCart() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiService.get('cart.php');
      _items = (data['items'] as List).map((e) => CartItem.fromJson(e)).toList();
      _total = double.parse(data['total'].toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addToCart(int bookId, {int quantity = 1}) async {
    await ApiService.post('cart.php', {'book_id': bookId, 'quantity': quantity});
    await fetchCart();
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    await ApiService.put('cart.php', {'cart_item_id': cartItemId, 'quantity': quantity});
    await fetchCart();
  }

  Future<void> removeItem(int cartItemId) async {
    await ApiService.delete('cart.php?cart_item_id=$cartItemId');
    await fetchCart();
  }

  void clearLocal() {
    _items = [];
    _total = 0.0;
    notifyListeners();
  }
}
