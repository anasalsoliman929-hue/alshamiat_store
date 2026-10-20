import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/all_providers.dart';
import '../../data/models/invoice_with_items.dart';
import '../customers/screens/customers_screens.dart' show exportSaleInvoicePdf;
import '../suppliers/screens/suppliers_screens.dart' show exportPurchaseInvoicePdf;

enum _RangeMode { day, week }

class InvoicesBrowserScreen extends ConsumerStatefulWidget {
  const InvoicesBrowserScreen({super.key});

  @override
  ConsumerState<InvoicesBrowserScreen> createState() =>
      _InvoicesBrowserScreenState();
}

class _InvoicesBrowserScreenState extends ConsumerState<InvoicesBrowserScreen> {
  _RangeMode _mode = _RangeMode.day;
  DateTime _anchor = DateTime.now();

  DateTime get _start {
    if (_mode == _RangeMode.day) {
      return DateTime(_anchor.year, _anchor.month, _anchor.day);
    }
    // بداية الأسبوع = الاثنين
    final startOfDay = DateTime(_anchor.year, _anchor.month, _anchor.day);
    return startOfDay.subtract(Duration(days: startOfDay.weekday - 1));
  }

  DateTime get _end => _mode == _RangeMode.day
      ? _start.add(const Duration(days: 1))
      : _start.add(const Duration(days: 7));

  String get _rangeLabel {
    final f = DateFormat('yyyy/MM/dd');
    if (_mode == _RangeMode.day) return f.format(_start);
    final lastDay = _end.subtract(const Duration(days: 1));
    return '${f.format(_start)} → ${f.format(lastDay)}';
  }

  void _shift(int direction) {
    setState(() {
      _anchor = _mode == _RangeMode.day
          ? _anchor.add(Duration(days: direction))
          : _anchor.add(Duration(days: 7 * direction));
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = InvoicesRange(start: _start, end: _end);
    final dataAsync = ref.watch(invoicesForRangeProvider(range));

    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            SegmentedButton<_RangeMode>(
              segments: const [
                ButtonSegment(value: _RangeMode.day, label: Text('اليوم')),
                ButtonSegment(value: _RangeMode.week, label: Text('الأسبوع')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shift(1),
                ),
                Expanded(
                  child: Text(_rangeLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
              ],
            ),
          ]),
        ),
        Expanded(
          child: dataAsync.when(
            data: (data) => _CombinedInvoicesList(data: data),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ: $e')),
          ),
        ),
      ]),
    );
  }
}

class _CombinedInvoicesList extends ConsumerWidget {
  final InvoicesRangeData data;
  const _CombinedInvoicesList({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = <_Entry>[
      ...data.sales.map((e) => _Entry.sale(e)),
      ...data.purchases.map((e) => _Entry.purchase(e)),
    ]..sort((a, b) => b.date.compareTo(a.date));

    if (entries.isEmpty) {
      return const Center(child: Text('لا توجد فواتير في هذه الفترة'));
    }

    final usdFormat = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    return Column(children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [
              const Text('مبيعات', style: TextStyle(fontSize: 12)),
              Text(usdFormat.format(data.salesTotal),
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ]),
            Column(children: [
              const Text('مشتريات', style: TextStyle(fontSize: 12)),
              Text(usdFormat.format(data.purchasesTotal),
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold)),
            ]),
            Column(children: [
              const Text('الصافي', style: TextStyle(fontSize: 12)),
              Text(usdFormat.format(data.salesTotal - data.purchasesTotal),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final e = entries[i];
            final isSale = e.isSale;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: Icon(
                  isSale ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isSale ? Colors.green : Colors.orange,
                ),
                title: Row(children: [
                  Text(isSale ? 'بيع' : 'شراء',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSale ? Colors.green : Colors.orange)),
                  const SizedBox(width: 8),
                  Text(usdFormat.format(e.total)),
                ]),
                subtitle: Text(
                    '${DateFormat('yyyy/MM/dd - HH:mm').format(e.date)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.picture_as_pdf,
                      color: Colors.red, size: 20),
                  onPressed: () async {
                    if (isSale) {
                      final customer = await ref
                          .read(customerRepositoryProvider)
                          .getCustomerById(e.sale!.invoice.customerId);
                      if (customer != null && context.mounted) {
                        exportSaleInvoicePdf(context, ref, e.sale!, customer);
                      }
                    } else {
                      final supplier = await ref
                          .read(supplierRepositoryProvider)
                          .getSupplierById(e.purchase!.invoice.supplierId);
                      if (supplier != null && context.mounted) {
                        exportPurchaseInvoicePdf(
                            context, ref, e.purchase!, supplier);
                      }
                    }
                  },
                ),
                children: [
                  ...(isSale
                      ? e.sale!.items.map((d) => ListTile(
                          dense: true,
                          title: Text(d.productName),
                          subtitle: Text(
                              '${d.item.quantity} × ${usdFormat.format(d.item.unitPriceUsd)}'),
                          trailing: Text(usdFormat.format(d.totalUsd)),
                        ))
                      : e.purchase!.items.map((d) => ListTile(
                          dense: true,
                          title: Text(d.productName),
                          subtitle: Text(
                              '${d.item.quantity} × ${usdFormat.format(d.item.unitPurchasePriceUsd)}'),
                          trailing: Text(usdFormat.format(d.totalUsd)),
                        ))),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _Entry {
  final bool isSale;
  final DateTime date;
  final double total;
  final InvoiceWithItems? sale;
  final SupplierInvoiceWithItems? purchase;

  _Entry._(
      {required this.isSale,
      required this.date,
      required this.total,
      this.sale,
      this.purchase});

  factory _Entry.sale(InvoiceWithItems inv) => _Entry._(
      isSale: true,
      date: inv.invoice.date,
      total: inv.totalUsd,
      sale: inv);

  factory _Entry.purchase(SupplierInvoiceWithItems inv) => _Entry._(
      isSale: false,
      date: inv.invoice.date,
      total: inv.totalUsd,
      purchase: inv);
}
