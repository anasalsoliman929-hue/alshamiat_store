import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/all_providers.dart';
import '../../../shared/widgets/currency_display.dart';
import '../../customers/screens/customers_screens.dart' show AddInvoiceScreen;
import 'add_edit_product_screen.dart';
import 'archived_products_screen.dart';

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'بيع سريع (زبون عادي)',
            onPressed: () => _startQuickSale(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'المؤرشفة',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const ArchivedProductsScreen())),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'بحث عن منتج...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) =>
                  ref.read(productSearchQueryProvider.notifier).state = v,
            ),
          ),
        ),
      ),
      body: productsAsync.when(
        data: (products) => products.isEmpty
            ? const Center(child: Text('لا توجد منتجات حالياً'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: products.length,
                itemBuilder: (_, i) => _ProductCard(product: products[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "ProductsListScreen",
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddEditProductScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _startQuickSale(BuildContext context, WidgetRef ref) async {
    try {
      final walkIn = await ref.read(walkInCustomerProvider.future);
      if (!context.mounted) return;
      Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => AddInvoiceScreen(customer: walkIn, quickSale: true)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذّر بدء البيع السريع: $e')));
      }
    }
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  Color _qtyColor(double qty) {
    if (qty <= 0) return Colors.red;
    if (qty <= AppConstants.lowStockThreshold) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddEditProductScreen(product: product))),
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(children: [
          Text(product.category),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _qtyColor(product.quantity).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'الكمية: ${product.quantity} ${product.unit}',
              style: TextStyle(
                color: _qtyColor(product.quantity),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ]),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CurrencyDisplay(amountUsd: product.salePriceUsd),
            GestureDetector(
              onTap: () => _handleArchive(context, ref),
              child: const Icon(Icons.archive_outlined,
                  color: Colors.orange, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _handleArchive(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('أرشفة المنتج'),
        content: Text(
          'هل تريد أرشفة "${product.name}"؟\n\n'
          'المنتجات المرتبطة بفواتير لا يمكن أرشفتها.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await ref
                  .read(productActionsProvider)
                  .tryArchiveProduct(product.id);
              if (!context.mounted) return;
              if (result == 'archived') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('✅ تم أرشفة المنتج'),
                  backgroundColor: Colors.orange,
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('❌ لا يمكن أرشفة منتج مرتبط بفواتير'),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: const Text('أرشفة',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
