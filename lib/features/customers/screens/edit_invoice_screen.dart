import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/invoice_with_items.dart';
import '../../../providers/all_providers.dart';
import '../../../shared/widgets/currency_display.dart';

class EditInvoiceScreen extends ConsumerStatefulWidget {
  final InvoiceWithItems invoiceWithItems;
  final int customerId;

  const EditInvoiceScreen({
    super.key,
    required this.invoiceWithItems,
    required this.customerId,
  });

  @override
  ConsumerState<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends ConsumerState<EditInvoiceScreen> {
  final _notesCtrl = TextEditingController();
  final List<_EditInvoiceRow> _rows = [];
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.invoiceWithItems.invoice.notes;
    _selectedDate = widget.invoiceWithItems.invoice.date;

    for (final detail in widget.invoiceWithItems.items) {
      if (detail.product != null) {
        // الكمية المتاحة = مخزون حالي + كمية الفاتورة القديمة
        final availableProduct = detail.product!.copyWith(
          quantity: detail.product!.quantity + detail.item.quantity,
        );
        _rows.add(_EditInvoiceRow(
          product: availableProduct,
          initialQty: detail.item.quantity.toString(),
          initialPrice: detail.item.unitPriceUsd.toString(),
        ));
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  double get _total => _rows.fold(0, (s, r) => s + r.lineTotal);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _addRow(Product product) {
    if (_rows.any((r) => r.product.id == product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} مضاف مسبقاً')));
      return;
    }
    setState(() => _rows.add(_EditInvoiceRow(product: product)));
  }

  Future<void> _save() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أضف منتجاً واحداً على الأقل')));
      return;
    }
    for (final row in _rows) {
      final qty = double.tryParse(row.qtyCtrl.text) ?? 0;
      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تحقق من كمية "${row.product.name}"')));
        return;
      }
      if (qty > row.product.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'كمية "${row.product.name}" تتجاوز المتاح (${row.product.quantity})'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    final newItems = _rows.map((row) {
      final qty = double.parse(row.qtyCtrl.text);
      final price =
          double.tryParse(row.priceCtrl.text) ?? row.product.salePriceUsd;
      return InvoiceItemDetail(
        item: CustomerInvoiceItem(
          id: 0,
          invoiceId: widget.invoiceWithItems.invoice.id,
          productId: row.product.id,
          quantity: qty,
          unitPriceUsd: price,
          productNameSnapshot: row.product.name,
        ),
        product: row.product,
      );
    }).toList();

    await ref.read(customerActionsProvider).updateInvoiceWithItems(
          invoiceId: widget.invoiceWithItems.invoice.id,
          customerId: widget.customerId,
          newItems: newItems,
          notes: _notesCtrl.text.trim(),
          date: _selectedDate,
        );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الفاتورة'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('حفظ',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ListTile(
                tileColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                leading: const Icon(Icons.calendar_today),
                title: Text(
                    'التاريخ: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}'),
                trailing: const Icon(Icons.edit),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إضافة منتج'),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _EditProductPickerSheet(
                    onSelect: _addRow,
                    excludeIds: _rows.map((r) => r.product.id).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_rows.isEmpty)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('لا توجد منتجات',
                            style: TextStyle(color: Colors.grey))))
              else
                ..._rows.asMap().entries.map((e) => _EditItemCard(
                      row: e.value,
                      onRemove: () => setState(() {
                        _rows[e.key].dispose();
                        _rows.removeAt(e.key);
                      }),
                      onChanged: () => setState(() {}),
                    )),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        // شريط الإجمالي
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي الجديد:',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              CurrencyDisplay(
                amountUsd: _total,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _EditItemCard extends StatelessWidget {
  final _EditInvoiceRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _EditItemCard(
      {required this.row, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(row.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            Text('المتاح: ${row.product.quantity} ${row.product.unit}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            IconButton(
                icon: const Icon(Icons.remove_circle,
                    color: Colors.red, size: 20),
                onPressed: onRemove),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: row.qtyCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'الكمية (${row.product.unit})',
                    border: const OutlineInputBorder(),
                    isDense: true),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'السعر (\$)',
                    border: OutlineInputBorder(),
                    isDense: true),
                onChanged: (_) => onChanged(),
              ),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('الإجمالي',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('\$${row.lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.teal)),
            ]),
          ]),
        ]),
      ),
    );
  }
}

class _EditProductPickerSheet extends ConsumerStatefulWidget {
  final Function(Product) onSelect;
  final List<int> excludeIds;
  const _EditProductPickerSheet(
      {required this.onSelect, required this.excludeIds});

  @override
  ConsumerState<_EditProductPickerSheet> createState() =>
      _EditProductPickerSheetState();
}

class _EditProductPickerSheetState
    extends ConsumerState<_EditProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Text('اختر منتجاً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
                hintText: 'بحث...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: productsAsync.when(
              data: (products) {
                final filtered = products
                    .where((p) => !widget.excludeIds.contains(p.id))
                    .where((p) => _query.isEmpty
                        ? true
                        : p.name.toLowerCase().contains(_query.toLowerCase()))
                    .toList();
                if (filtered.isEmpty)
                  return const Center(child: Text('لا توجد منتجات'));
                return ListView.builder(
                  controller: scrollCtrl,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final outOfStock = p.quantity <= 0;
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                          'المتاح: ${p.quantity} ${p.unit}  |  \$${p.salePriceUsd.toStringAsFixed(2)}'),
                      trailing: outOfStock
                          ? const Chip(
                              label: Text('نفذ',
                                  style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.red)
                          : null,
                      enabled: !outOfStock,
                      onTap: outOfStock
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onSelect(p);
                            },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EditInvoiceRow {
  final Product product;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _EditInvoiceRow(
      {required this.product, String? initialQty, String? initialPrice})
      : qtyCtrl = TextEditingController(text: initialQty ?? '1'),
        priceCtrl = TextEditingController(
            text: initialPrice ?? product.salePriceUsd.toStringAsFixed(2));

  double get lineTotal {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    return qty * price;
  }

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}
