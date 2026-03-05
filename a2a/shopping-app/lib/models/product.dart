/// A product from the business agent catalog.
class Product {
  final String productId;
  final String name;
  final String? description;
  final List<String> images;
  final String? brandName;
  final String? price;
  final String? priceCurrency;
  final String? category;

  const Product({
    required this.productId,
    required this.name,
    this.description,
    this.images = const [],
    this.brandName,
    this.price,
    this.priceCurrency,
    this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final offers = json['offers'] as Map<String, dynamic>?;
    final brand = json['brand'] as Map<String, dynamic>?;

    List<String> parseImages(dynamic img) {
      if (img is List) return img.map((e) => e.toString()).toList();
      if (img is String) return [img];
      return [];
    }

    return Product(
      productId: json['productID'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      images: parseImages(json['image']),
      brandName: brand?['name'] as String?,
      price: offers?['price']?.toString(),
      priceCurrency: offers?['priceCurrency'] as String? ?? 'USD',
      category: json['category'] as String?,
    );
  }

  String get displayPrice {
    if (price == null) return '';
    return '\$$price';
  }
}

/// Wrapper for product search results.
class ProductResults {
  final List<Product> results;
  final String? content;

  const ProductResults({required this.results, this.content});

  factory ProductResults.fromJson(Map<String, dynamic> json) {
    final list = json['results'] as List<dynamic>? ?? [];
    return ProductResults(
      results: list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
      content: json['content'] as String?,
    );
  }
}
