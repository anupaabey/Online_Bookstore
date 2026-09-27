class OrderItem {
  final int bookId;
  final String title;
  final String author;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.bookId,
    required this.title,
    required this.author,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      bookId: int.parse(json['book_id'].toString()),
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      quantity: int.parse(json['quantity'].toString()),
      unitPrice: double.parse(json['unit_price'].toString()),
    );
  }
}

class BookOrder {
  final int id;
  final int userId;
  final double totalAmount;
  final String status;
  final String shippingAddress;
  final String paymentMethod;
  final String createdAt;
  final String? customerName;
  final String? customerEmail;
  final List<OrderItem> items;

  BookOrder({
    required this.id,
    required this.userId,
    required this.totalAmount,
    required this.status,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.createdAt,
    this.customerName,
    this.customerEmail,
    this.items = const [],
  });

  factory BookOrder.fromJson(Map<String, dynamic> json) {
    return BookOrder(
      id: int.parse(json['order_id'].toString()),
      userId: int.parse(json['user_id'].toString()),
      totalAmount: double.parse(json['total_amount'].toString()),
      status: json['status'] ?? 'pending',
      shippingAddress: json['shipping_address'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      createdAt: json['created_at'] ?? '',
      customerName: json['full_name'],
      customerEmail: json['email'],
      items: json['items'] != null
          ? (json['items'] as List).map((e) => OrderItem.fromJson(e)).toList()
          : const [],
    );
  }
}
