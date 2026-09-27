class Book {
  final int id;
  final String title;
  final String author;
  final String isbn;
  final String description;
  final double price;
  final int stockQty;
  final int? categoryId;
  final String? categoryName;
  final String? coverImage;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.description,
    required this.price,
    required this.stockQty,
    this.categoryId,
    this.categoryName,
    this.coverImage,
  });

  bool get inStock => stockQty > 0;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: int.parse(json['book_id'].toString()),
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      isbn: json['isbn'] ?? '',
      description: json['description'] ?? '',
      price: double.parse(json['price'].toString()),
      stockQty: int.parse(json['stock_qty'].toString()),
      categoryId: json['category_id'] != null
          ? int.tryParse(json['category_id'].toString())
          : null,
      categoryName: json['category_name'],
      coverImage: json['cover_image'],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'isbn': isbn,
        'description': description,
        'price': price,
        'stock_qty': stockQty,
        'category_id': categoryId,
      };
}
