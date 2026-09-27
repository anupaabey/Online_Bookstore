class CartItem {
  final int cartItemId;
  final int bookId;
  final String title;
  final String author;
  final double price;
  final int quantity;
  final int stockQty;
  final double subtotal;

  CartItem({
    required this.cartItemId,
    required this.bookId,
    required this.title,
    required this.author,
    required this.price,
    required this.quantity,
    required this.stockQty,
    required this.subtotal,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartItemId: int.parse(json['cart_item_id'].toString()),
      bookId: int.parse(json['book_id'].toString()),
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      price: double.parse(json['price'].toString()),
      quantity: int.parse(json['quantity'].toString()),
      stockQty: int.parse(json['stock_qty'].toString()),
      subtotal: double.parse(json['subtotal'].toString()),
    );
  }
}
