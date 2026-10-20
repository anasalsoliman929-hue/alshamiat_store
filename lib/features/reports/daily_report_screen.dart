import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/all_providers.dart';
import '../../shared/widgets/currency_display.dart';
import '../../shared/widgets/backup_restore_widget.dart';
import '../notifications/notifications_screen.dart';
import '../expenses/expenses_losses_screen.dart';
import 'invoices_browser_screen.dart';

class DailyReportScreen extends ConsumerWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(dailyReportProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final dateFormat = DateFormat('EEEE، d MMMM yyyy', 'ar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقرير اليومي'),
        actions: [
          Stack(alignment: Alignment.center, children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'الإشعارات',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
            notificationsAsync.maybeWhen(
              data: (d) => d.totalCount > 0
                  ? Positioned(
                      top: 8,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text('${d.totalCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10)),
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ]),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dailyReportProvider);
              ref.invalidate(notificationsProvider);
            },
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dailyReportProvider);
            ref.invalidate(notificationsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(dateFormat.format(DateTime.now()),
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 16),

              Card(
                child: ListTile(
                  leading: Icon(Icons.receipt_long,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('الفواتير الكاملة (يوم / أسبوع)'),
                  subtitle: const Text('عرض جميع فواتير البيع والشراء'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const InvoicesBrowserScreen())),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_outlined, color: Colors.deepOrange),
                  title: const Text('المصاريف الشخصية وخسائر المنتجات'),
                  subtitle: const Text('تسجيل ومتابعة المصاريف والخسائر'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const ExpensesLossesScreen())),
                ),
              ),
              const SizedBox(height: 16),

              _SectionHeader(title: 'حركة اليوم', icon: Icons.today),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _StatCard(title: 'مبيعات اليوم', value: report.todayCustomerInvoicesTotal, color: Colors.blue, icon: Icons.shopping_cart)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(title: 'تحصيلات اليوم', value: report.todayCustomerPaymentsTotal, color: Colors.green, icon: Icons.payments)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _StatCard(title: 'مشتريات اليوم', value: report.todaySupplierInvoicesTotal, color: Colors.orange, icon: Icons.local_shipping)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(title: 'مدفوعات للموردين', value: report.todaySupplierPaymentsTotal, color: Colors.purple, icon: Icons.payment)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _StatCard(title: 'مصاريف اليوم', value: report.todayExpensesTotal, color: Colors.red, icon: Icons.money_off)),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(title: 'خسائر اليوم', value: report.todayLossesValue, color: Colors.deepOrange, icon: Icons.broken_image_outlined)),
              ]),

              const SizedBox(height: 24),
              _SectionHeader(title: 'الأرصدة العامة', icon: Icons.account_balance_wallet),
              const SizedBox(height: 8),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _BalanceRow(label: 'المستحق لك على الزبائن', value: report.totalReceivables, positiveColor: Colors.green),
                  const Divider(),
                  _BalanceRow(label: 'المستحق عليك للموردين', value: report.totalPayables, positiveColor: Colors.red),
                  const Divider(),
                  _BalanceRow(label: 'الصافي', value: report.totalReceivables - report.totalPayables, positiveColor: Colors.teal, bold: true),
                ]),
              )),

              const SizedBox(height: 24),
              _SectionHeader(title: 'قيمة المخزون', icon: Icons.inventory_2),
              const SizedBox(height: 8),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _BalanceRow(label: 'قيمة المخزون بسعر البيع', value: report.inventorySaleValue),
                  const Divider(),
                  _BalanceRow(label: 'قيمة المخزون بسعر الشراء', value: report.inventoryPurchaseValue),
                  const Divider(),
                  _BalanceRow(label: 'الربح المتوقع (إن بيع الكل)', value: report.potentialProfit, positiveColor: Colors.green, bold: true),
                ]),
              )),

              const SizedBox(height: 24),
              _SectionHeader(title: 'تنبيهات نفاذ المخزون', icon: Icons.warning_amber),
              const SizedBox(height: 8),
              report.lowStockProducts.isEmpty
                  ? const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('لا توجد منتجات منخفضة الكمية ✅')))
                  : Card(child: Column(children: report.lowStockProducts.map((p) {
                      final out = p.quantity <= 0;
                      return ListTile(
                        leading: Icon(out ? Icons.error : Icons.warning, color: out ? Colors.red : Colors.orange),
                        title: Text(p.name),
                        trailing: Text('${p.quantity} ${p.unit}', style: TextStyle(fontWeight: FontWeight.bold, color: out ? Colors.red : Colors.orange)),
                      );
                    }).toList())),

              const SizedBox(height: 24),
              const BackupRestoreWidget(showTitle: false),
              const SizedBox(height: 16),
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
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.teal, size: 20),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          ]),
          const SizedBox(height: 8),
          CurrencyDisplay(amountUsd: value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ]),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final double value;
  final Color? positiveColor;
  final bool bold;
  const _BalanceRow({required this.label, required this.value, this.positiveColor, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          CurrencyDisplay(amountUsd: value, showBoth: false, style: TextStyle(fontWeight: FontWeight.bold, fontSize: bold ? 16 : 14, color: positiveColor ?? Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}
