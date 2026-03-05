import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/shop_state.dart';
import '../widgets/product_card.dart';

/// Product catalog with search bar and product grid.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopState>();
    return Column(
      children: [
        // Search bar.
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search products...',
            leading: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.search),
            ),
            trailing: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    shop.browseCatalog();
                  },
                ),
            ],
            onChanged: (_) => setState(() {}),
            onSubmitted: (query) {
              if (query.trim().isNotEmpty) {
                shop.searchProducts(query.trim());
              } else {
                shop.browseCatalog();
              }
            },
          ),
        ),

        // Error.
        if (shop.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(shop.error!)),
                  ],
                ),
              ),
            ),
          ),

        // Loading.
        if (shop.isLoading) const LinearProgressIndicator(),

        // Product grid.
        Expanded(
          child: shop.products.isEmpty && !shop.isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storefront,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No products found',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: shop.browseCatalog,
                        child: const Text('Browse Catalog'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: shop.products.length,
                  itemBuilder: (context, index) {
                    final product = shop.products[index];
                    return ProductCard(
                      product: product,
                      isLoading: shop.isLoading,
                      onAddToCart: () => shop.addToCheckout(product.productId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
