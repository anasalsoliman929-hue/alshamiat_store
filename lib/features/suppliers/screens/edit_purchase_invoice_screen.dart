import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/invoice_with_items.dart';
import '../../../providers/all_providers.dart';
import '../../../shared/widgets/currency_display.dart';

class EditPurchaseInvoiceScreen extends ConsumerStatefulWidget {
  final SupplierInvoiceWithItems invoiceWithItems;
  final int supplierId;

  const EditPurchaseInvoiceScreen({
    super.key,
    required this.invoiceWithItems,
    required this.supplierId,
  });

  @override
  ConsumerState<EditPurchaseInvoiceScreen> createState() =>
      _EditPurchaseInvoiceScreenState();
}

class _EditPurchaseInvoiceScreenState
    extends ConsumerState<EditPurchaseInvoiceScreen> {
  final _notesCtrl = TextEditingController();
  final List<_EditPurchaseRow> _rows = [];
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.invoiceWithItems.invoice.notes;
    _selectedDate = widget.invoiceWithItems.invoice.date;

    for (final detail in widget.invoiceWithItems.items) {
      if (detail.product != null) {
        _rows.add(_EditPurchaseRow.existing(
          product: detail.product!,
          initialQty: detail.item.quantity.toString(),
          initialPrice: detail.item.unitPurchasePriceUsd.toString(),
        ));
      }
      // إن كان المنتج محذوفاً (product == null)، لا يمكن تعديل هذا السطر
      // لعدم وجود مرجع له بعد الآن؛ يظهر فقط في العرض غير القابل للتعديل
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

  void _addExistingProductRow(Product product) {
    if (_rows.any((r) => r.existingProduct?.id == product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} مضاف مسبقاً')));
      return;
    }
    setState(() => _rows.add(_EditPurchaseRow.existing(product: product)));
  }

  void _addNewProductRow() {
    setState(() => _rows.add(_EditPurchaseRow.newProduct()));
  }

  Future<void> _save() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أضف منتجاً واحداً على الأقل')));
      return;
    }

    final lines = <PurchaseLineInput>[];

    for (final row in _rows) {
      final qty = double.tryParse(row.qtyCtrl.text) ?? 0;
      final price = double.tryParse(row.priceCtrl.text) ?? 0;

      if (qty <= 0 || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تحقق من كمية/سعر "${row.displayName}"')));
        return;
      }

      if (row.isNewProduct) {
        final name = row.nameCtrl.text.trim();
        if (name.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('يرجى إدخال اسم المنتج الجديد')));
          return;
        }
        final salePrice = double.tryParse(row.salePriceCtrl.text);
        if (salePrice == null || salePrice <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('يرجى إدخال سعر بيع صحيح لـ"$name"')));
          return;
        }
        lines.add(PurchaseLineInput(
          productId: null,
          draft: NewProductDraft(
            name: name,
            category: row.selectedCategory,
            unit: row.selectedUnit,
            salePriceUsd: salePrice,
          ),
          quantity: qty,
          unitPurchasePriceUsd: price,
        ));
      } else {
        lines.add(PurchaseLineInput(
          productId: row.existingProduct!.id,
          quantity: qty,
          unitPurchasePriceUsd: price,
        ));
      }
    }

    await ref.read(supplierActionsProvider).updatePurchaseInvoiceWithItems(
          invoiceId: widget.invoiceWithItems.invoice.id,
          supplierId: widget.supplierId,
          newLines: lines,
          notes: _notesCtrl.text.trim(),
          date: _selectedDate,
        );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd');
    // عناصر محذوفة (المنتج لم يعد موجوداً) تُعرض للقراءة فقط
    final deletedItems = widget.invoiceWithItems.items
        .where((d) => d.product == null)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل فاتورة الشراء'),
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
                    'التاريخ: ${dateFormat.format(_selectedDate)}'),
                trailing: const Icon(Icons.edit),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),

              if (deletedItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'منتجات محذوفة من هذه الفاتورة (لا يمكن تعديلها):',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      ...deletedItems.map((d) => Text(
                          '• ${d.productName} (${d.item.quantity})',
                          style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                ),

              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('منتج موجود'),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _EditProductPickerSheet(
                        onSelect: _addExistingProductRow,
                        excludeIds: _rows
                            .where((r) => !r.isNewProduct)
                            .map((r) => r.existingProduct!.id)
                            .toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_box),
                    label: const Text('منتج جديد'),
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.teal),
                    onPressed: _addNewProductRow,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              if (_rows.isEmpty)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('لا توجد منتجات',
                            style: TextStyle(color: Colors.grey))))
              else
                ..._rows.asMap().entries.map((e) => _EditPurchaseItemCard(
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

class _EditPurchaseItemCard extends StatelessWidget {
  final _EditPurchaseRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _EditPurchaseItemCard(
      {required this.row, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: row.isNewProduct ? Colors.teal.withOpacity(0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (row.isNewProduct)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.fiber_new, color: Colors.teal, size: 18),
                ),
              Expanded(
                child: row.isNewProduct
                    ? TextField(
                        controller: row.nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المنتج الجديد',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => onChanged(),
                      )
                    : Text(row.existingProduct!.name,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold)),
              ),
              IconButton(
                  icon: const Icon(Icons.remove_circle,
                      color: Colors.red, size: 20),
                  onPressed: onRemove),
            ]),
            const SizedBox(height: 8),
            if (row.isNewProduct) ...[
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: row.selectedCategory,
                    decoration: const InputDecoration(
                        labelText: 'الفئة',
                        isDense: true,
                        border: OutlineInputBorder()),
                    items: AppConstants.productCategories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        row.selectedCategory = v;
                        onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: row.selectedUnit,
                    decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        isDense: true,
                        border: OutlineInputBorder()),
                    items: AppConstants.productUnits
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        row.selectedUnit = v;
                        onChanged();
                      }
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: row.salePriceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'سعر البيع المقترح (\$)',
                    isDense: true,
                    border: OutlineInputBorder()),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    'المخزون الحالي (شامل هذه الفاتورة): ${row.existingProduct!.quantity} ${row.existingProduct!.unit}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: row.qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'الكمية المشتراة',
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
                      labelText: 'سعر الشراء (\$)',
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
          ],
        ),
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
          const Text('اختر منتجاً موجوداً',
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
                  return const Center(child: Text('لا توجد منتجات مطابقة'));
                return ListView.builder(
                  controller: scrollCtrl,
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                          'المخزون: ${p.quantity} ${p.unit}  |  آخر شراء: \$${p.purchasePriceUsd.toStringAsFixed(2)}'),
                      onTap: () {
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

class _EditPurchaseRow {
  final bool isNewProduct;
  final Product? existingProduct;

  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController salePriceCtrl;
  String selectedCategory;
  String selectedUnit;

  _EditPurchaseRow._({
    required this.isNewProduct,
    this.existingProduct,
    required this.qtyCtrl,
    required this.priceCtrl,
    required this.nameCtrl,
    required this.salePriceCtrl,
    required this.selectedCategory,
    required this.selectedUnit,
  });

  factory _EditPurchaseRow.existing({
    required Product product,
    String? initialQty,
    String? initialPrice,
  }) {
    return _EditPurchaseRow._(
      isNewProduct: false,
      existingProduct: product,
      qtyCtrl: TextEditingController(text: initialQty ?? '1'),
      priceCtrl: TextEditingController(
          text: initialPrice ?? product.purchasePriceUsd.toStringAsFixed(2)),
      nameCtrl: TextEditingController(),
      salePriceCtrl: TextEditingController(),
      selectedCategory: product.category,
      selectedUnit: product.unit,
    );
  }

  factory _EditPurchaseRow.newProduct() {
    return _EditPurchaseRow._(
      isNewProduct: true,
      qtyCtrl: TextEditingController(text: '1'),
      priceCtrl: TextEditingController(),
      nameCtrl: TextEditingController(),
      salePriceCtrl: TextEditingController(),
      selectedCategory: AppConstants.productCategories.first,
      selectedUnit: AppConstants.productUnits.first,
    );
  }

  String get displayName => isNewProduct
      ? (nameCtrl.text.isEmpty ? 'منتج جديد' : nameCtrl.text)
      : existingProduct!.name;

  double get lineTotal {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    return qty * price;
  }

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    nameCtrl.dispose();
    salePriceCtrl.dispose();
  }
}
