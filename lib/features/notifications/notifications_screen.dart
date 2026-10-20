import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/all_providers.dart';
import '../../shared/widgets/currency_display.dart';
import '../customers/screens/customers_screens.dart';
import '../suppliers/screens/suppliers_screens.dart';
import '../products/screens/products_list_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(notificationsProvider),
          ),
        ],
      ),
      body: dataAsync.when(
        data: (data) => data.totalCount == 0
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('لا توجد تنبيهات حالياً ✅'),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (data.outOfStockProducts.isNotEmpty) ...[
                      _SectionHeader(
                          title: 'نفاذ المخزون',
                          icon: Icons.error,
                          color: Colors.red,
                          count: data.outOfStockProducts.length),
                      const SizedBox(height: 6),
                      Card(
                        child: Column(
                          children: data.outOfStockProducts
                              .map((p) => ListTile(
                                    leading: const Icon(Icons.error,
                                        color: Colors.red),
                                    title: Text(p.name),
                                    subtitle: const Text('نفدت الكمية بالكامل'),
                                    trailing: Text('0 ${p.unit}',
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold)),
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ProductsListScreen())),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (data.lowStockProducts.isNotEmpty) ...[
                      _SectionHeader(
                          title: 'مخزون منخفض',
                          icon: Icons.warning_amber,
                          color: Colors.orange,
                          count: data.lowStockProducts.length),
                      const SizedBox(height: 6),
                      Card(
                        child: Column(
                          children: data.lowStockProducts
                              .map((p) => ListTile(
                                    leading: const Icon(Icons.warning_amber,
                                        color: Colors.orange),
                                    title: Text(p.name),
                                    subtitle: const Text('اقترب النفاذ'),
                                    trailing: Text('${p.quantity} ${p.unit}',
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold)),
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const ProductsListScreen())),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (data.customersWithDebt.isNotEmpty) ...[
                      _SectionHeader(
                          title: 'مستحقات على الزبائن',
                          icon: Icons.person,
                          color: Colors.blue,
                          count: data.customersWithDebt.length),
                      const SizedBox(height: 6),
                      Card(
                        child: Column(
                          children: data.customersWithDebt
                              .map((a) => ListTile(
                                    leading: const Icon(Icons.person,
                                        color: Colors.blue),
                                    title: Text(a.customer.name),
                                    trailing: CurrencyDisplay(
                                        amountUsd: a.balance,
                                        showBoth: false,
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold)),
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                CustomerDetailsScreen(
                                                    customer: a.customer))),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (data.suppliersOwed.isNotEmpty) ...[
                      _SectionHeader(
                          title: 'مستحقات للموردين',
                          icon: Icons.local_shipping,
                          color: Colors.purple,
                          count: data.suppliersOwed.length),
                      const SizedBox(height: 6),
                      Card(
                        child: Column(
                          children: data.suppliersOwed
                              .map((a) => ListTile(
                                    leading: const Icon(Icons.local_shipping,
                                        color: Colors.purple),
                                    title: Text(a.supplier.name),
                                    trailing: CurrencyDisplay(
                                        amountUsd: a.balance,
                                        showBoth: false,
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold)),
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                SupplierDetailsScreen(
                                                    supplier: a.supplier))),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  const _SectionHeader(
      {required this.title,
      required this.icon,
      required this.color,
      required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    ]);
  }
}
