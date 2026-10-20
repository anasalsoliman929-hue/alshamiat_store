import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/all_providers.dart';

class ArchivedProductsScreen extends ConsumerWidget {
  const ArchivedProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات المؤرشفة')),
      body: archivedAsync.when(
        data: (products) => products.isEmpty
            ? const Center(child: Text('لا توجد منتجات مؤرشفة'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: products.length,
                itemBuilder: (_, i) =>
                    _ArchivedProductCard(product: products[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}

class _ArchivedProductCard extends ConsumerWidget {
  final Product product;
  const _ArchivedProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.archive, color: Colors.grey),
        title: Text(product.name,
            style: const TextStyle(color: Colors.grey)),
        subtitle: Text(
            '${product.category} — ${product.quantity} ${product.unit}'),
        trailing: TextButton.icon(
          icon: const Icon(Icons.unarchive, color: Colors.teal),
          label: const Text('إلغاء الأرشفة',
              style: TextStyle(color: Colors.teal)),
          onPressed: () async {
            await ref
                .read(productActionsProvider)
                .unarchiveProduct(product.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('✅ تم إعادة المنتج للقائمة'),
                backgroundColor: Colors.teal,
              ));
            }
          },
        ),
      ),
    );
  }
}
