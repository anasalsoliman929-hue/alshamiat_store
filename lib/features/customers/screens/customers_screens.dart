import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/invoice_with_items.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/all_providers.dart';
import '../../../shared/widgets/currency_display.dart';
import 'edit_invoice_screen.dart';

// ============================================================
// CUSTOMERS LIST
// ============================================================
class CustomersListScreen extends ConsumerWidget {
  const CustomersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الزبائن')),
      body: customersAsync.when(
        data: (customers) => customers.isEmpty
            ? const Center(child: Text('لا يوجد زبائن حالياً'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: customers.length,
                itemBuilder: (_, i) =>
                    _CustomerCard(customer: customers[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const AddEditCustomerScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  final Customer customer;
  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(customerBalanceProvider(customer.id));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => CustomerDetailsScreen(customer: customer))),
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(customer.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: customer.phone.isNotEmpty ? Text(customer.phone) : null,
        trailing: balanceAsync.when(
          data: (balance) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('المستحق',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              CurrencyDisplay(
                amountUsd: balance,
                showBoth: false,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: balance > 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          loading: () => const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, __) => const Text('-'),
        ),
      ),
    );
  }
}

// ============================================================
// ADD / EDIT CUSTOMER
// ============================================================
class AddEditCustomerScreen extends ConsumerStatefulWidget {
  final Customer? customer;
  const AddEditCustomerScreen({super.key, this.customer});

  @override
  ConsumerState<AddEditCustomerScreen> createState() =>
      _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState
    extends ConsumerState<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _notesCtrl;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final actions = ref.read(customerActionsProvider);
    if (isEditing) {
      await actions.updateCustomer(widget.customer!.copyWith(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ));
    } else {
      await actions.addCustomer(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(isEditing ? 'تعديل زبون' : 'إضافة زبون جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم الزبون', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  hintText: '09xxxxxxxx',
                  counterText: '',
                  border: OutlineInputBorder()),
              validator: Validators.requiredPhone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الزبون'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOMER DETAILS
// ============================================================
class CustomerDetailsScreen extends ConsumerWidget {
  final Customer customer;
  const CustomerDetailsScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(customerBalanceProvider(customer.id));
    final paymentsAsync = ref.watch(customerPaymentsProvider(customer.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'كشف حساب',
            onPressed: () => exportCustomerStatementPdf(context, ref, customer),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) =>
                        AddEditCustomerScreen(customer: customer))),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: Column(children: [
        // بطاقة الرصيد
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المبلغ المستحق',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              balanceAsync.when(
                data: (b) => CurrencyDisplay(
                  amountUsd: b,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: b > 0 ? Colors.red : Colors.green,
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('-'),
              ),
            ],
          ),
        ),

        if (customer.phone.isNotEmpty || customer.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              if (customer.phone.isNotEmpty)
                Text('الهاتف: ${customer.phone}'),
              if (customer.notes.isNotEmpty)
                Text('ملاحظات: ${customer.notes}'),
              const SizedBox(height: 8),
            ]),
          ),

        // أزرار سريعة
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('إضافة فاتورة'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddInvoiceScreen(customer: customer))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payments),
                label: const Text('إضافة دفعة'),
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddPaymentScreen(customer: customer))),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.assignment_return, color: Colors.deepOrange),
              label: const Text('فاتورة مرتجعة',
                  style: TextStyle(color: Colors.deepOrange)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.deepOrange)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => AddReturnScreen(customer: customer))),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(children: [
              const TabBar(
                labelColor: Colors.teal,
                tabs: [
                  Tab(text: 'الفواتير'),
                  Tab(text: 'الدفعات'),
                  Tab(text: 'المرتجعات'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [
                  _InvoicesList(customer: customer),
                  _PaymentsList(paymentsAsync: paymentsAsync),
                  _ReturnsList(customer: customer),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content:
            Text('سيتم حذف "${customer.name}" مع جميع فواتيره ودفعاته.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              ref.read(customerActionsProvider).deleteCustomer(customer.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INVOICES LIST
// ============================================================
class _InvoicesList extends ConsumerWidget {
  final Customer customer;
  const _InvoicesList({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerId = customer.id;
    final invoicesAsync =
        ref.watch(customerInvoicesWithItemsProvider(customerId));
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm');

    return invoicesAsync.when(
      data: (invoices) => invoices.isEmpty
          ? const Center(child: Text('لا توجد فواتير'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: invoices.length,
              itemBuilder: (_, i) {
                final inv = invoices[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: const Icon(Icons.receipt_long,
                        color: Colors.blueGrey),
                    title: Text(
                      '\$${inv.totalUsd.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(dateFormat.format(inv.invoice.date)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf,
                              color: Colors.red, size: 20),
                          tooltip: 'فاتورة PDF',
                          onPressed: () =>
                              exportSaleInvoicePdf(context, ref, inv, customer),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blue, size: 20),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => EditInvoiceScreen(
                                        invoiceWithItems: inv,
                                        customerId: customerId,
                                      ))),
                        ),
                      ],
                    ),
                    children: [
                      ...inv.items.map((d) => ListTile(
                            dense: true,
                            title: Text(d.productName),
                            subtitle: Text(
                                '${d.item.quantity} × \$${d.item.unitPriceUsd.toStringAsFixed(2)}'),
                            trailing: Text(
                                '\$${d.totalUsd.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          )),
                      if (inv.invoice.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Text('ملاحظات: ${inv.invoice.notes}',
                              style:
                                  const TextStyle(color: Colors.grey)),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }
}

/// يبني ويعرض كشف حساب كامل للزبون (كل الفواتير والدفعات) PDF
Future<void> exportCustomerStatementPdf(
    BuildContext context, WidgetRef ref, Customer customer) async {
  try {
    final service = PdfInvoiceService();
    final bytes = await runWithPdfLoadingDialog(context, () async {
      final repo = ref.read(customerRepositoryProvider);
      final invoices = await repo.getAllInvoicesWithItemsForCustomer(customer.id);
      final payments = await repo.getAllPaymentsForCustomer(customer.id);
      final returns = await repo.getAllReturnsForCustomer(customer.id);
      final rate = await ref.read(currentExchangeRateProvider.future);
      return service.buildCustomerStatementPdf(
        customerName: customer.name,
        customerPhone: customer.phone,
        invoices: invoices,
        payments: payments,
        returns: returns,
        exchangeRate: rate,
      );
    });
    await service.previewAndPrint(bytes, 'كشف_حساب_${customer.name}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر إنشاء كشف الحساب: $e')));
    }
  }
}

/// يبني ويعرض فاتورة مبيعات PDF قابلة للمعاينة/الطباعة/المشاركة
Future<void> exportSaleInvoicePdf(BuildContext context, WidgetRef ref,
    InvoiceWithItems inv, Customer customer) async {
  try {
    final service = PdfInvoiceService();
    final bytes = await runWithPdfLoadingDialog(context, () async {
      final rate = await ref.read(currentExchangeRateProvider.future);
      return service.buildSaleInvoicePdf(
        invoice: inv,
        customerName: customer.name,
        customerPhone: customer.phone,
        exchangeRate: rate,
      );
    });
    await service.previewAndPrint(bytes, 'فاتورة_مبيعات_${inv.invoice.id}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر إنشاء PDF: $e')));
    }
  }
}

// ============================================================
// PAYMENTS LIST
// ============================================================
class _PaymentsList extends ConsumerWidget {
  final AsyncValue<List<CustomerPayment>> paymentsAsync;
  const _PaymentsList({required this.paymentsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm');
    return paymentsAsync.when(
      data: (payments) => payments.isEmpty
          ? const Center(child: Text('لا توجد دفعات'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: payments.length,
              itemBuilder: (_, i) {
                final p = payments[i];
                return Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.payments, color: Colors.green),
                    title:
                        CurrencyDisplay(amountUsd: p.amountUsd, showBoth: false),
                    subtitle: Text(dateFormat.format(p.date) +
                        (p.notes.isNotEmpty ? '\n${p.notes}' : '')),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.blue, size: 20),
                      onPressed: () =>
                          _showEditPaymentDialog(context, ref, p),
                    ),
                  ),
                );
              }),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }

  void _showEditPaymentDialog(
      BuildContext context, WidgetRef ref, CustomerPayment payment) {
    final amountCtrl =
        TextEditingController(text: payment.amountUsd.toString());
    final notesCtrl = TextEditingController(text: payment.notes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الدفعة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'المبلغ (\$)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'ملاحظات', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) return;
              await ref.read(customerActionsProvider).updatePayment(
                    payment.copyWith(
                        amountUsd: amount, notes: notesCtrl.text.trim()),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RETURNS LIST (فواتير مرتجعة)
// ============================================================
class _ReturnsList extends ConsumerWidget {
  final Customer customer;
  const _ReturnsList({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final returnsAsync = ref.watch(customerReturnsProvider(customer.id));
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm');

    return returnsAsync.when(
      data: (returns) => returns.isEmpty
          ? const Center(child: Text('لا توجد فواتير مرتجعة'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: returns.length,
              itemBuilder: (_, i) {
                final ret = returns[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    leading: const Icon(Icons.assignment_return,
                        color: Colors.deepOrange),
                    title: Text(
                      '\$${ret.totalUsd.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        Text(dateFormat.format(ret.returnInvoice.date)),
                    children: [
                      ...ret.items.map((d) => ListTile(
                            dense: true,
                            title: Text(d.productName),
                            subtitle: Text(
                                '${d.item.quantity} × \$${d.item.unitPriceUsd.toStringAsFixed(2)}'),
                            trailing: Text(
                                '\$${d.totalUsd.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          )),
                      if (ret.returnInvoice.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Text('ملاحظات: ${ret.returnInvoice.notes}',
                              style: const TextStyle(color: Colors.grey)),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              }),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }
}

// ============================================================
// ADD INVOICE
// ============================================================
class AddInvoiceScreen extends ConsumerStatefulWidget {
  final Customer customer;
  final bool quickSale;
  const AddInvoiceScreen(
      {super.key, required this.customer, this.quickSale = false});

  @override
  ConsumerState<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends ConsumerState<AddInvoiceScreen> {
  final _notesCtrl = TextEditingController();
  final List<_InvoiceRow> _rows = [];
  DateTime _selectedDate = DateTime.now();

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
    setState(() => _rows.add(_InvoiceRow(product: product)));
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
              'كمية "${row.product.name}" تتجاوز المخزون (${row.product.quantity})'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    final items = _rows.map((row) {
      final qty = double.parse(row.qtyCtrl.text);
      final price =
          double.tryParse(row.priceCtrl.text) ?? row.product.salePriceUsd;
      return InvoiceItemDetail(
        item: CustomerInvoiceItem(
            id: 0,
            invoiceId: 0,
            productId: row.product.id,
            quantity: qty,
            unitPriceUsd: price,
            productNameSnapshot: row.product.name),
        product: row.product,
      );
    }).toList();

    await ref.read(customerActionsProvider).addInvoiceWithItems(
          customerId: widget.customer.id,
          items: items,
          notes: _notesCtrl.text.trim(),
          date: _selectedDate,
        );

    // بيع سريع: يُسجَّل مدفوعاً بالكامل فوراً (لا يبقى ديناً على
    // "زبون عادي")، وبذلك تبقى الحسابات دقيقة رغم عدم وجود زبون حقيقي.
    if (widget.quickSale) {
      await ref.read(customerActionsProvider).addPayment(
            customerId: widget.customer.id,
            amountUsd: _total,
            notes: 'دفع فوري - بيع سريع',
            date: _selectedDate,
          );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quickSale
            ? 'بيع سريع (بدون بيانات الزبون)'
            : 'فاتورة جديدة - ${widget.customer.name}'),
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
              _DateTile(date: _selectedDate, onTap: _pickDate),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إضافة منتج للفاتورة'),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _ProductPickerSheet(
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
                        child: Text('لم تُضف أي منتجات بعد',
                            style: TextStyle(color: Colors.grey))))
              else
                ..._rows.asMap().entries.map((e) => _InvoiceItemCard(
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
        _TotalBar(total: _total),
      ]),
    );
  }
}

// ============================================================
// ADD RETURN (فاتورة مرتجعة)
// ============================================================
class AddReturnScreen extends ConsumerStatefulWidget {
  final Customer customer;
  const AddReturnScreen({super.key, required this.customer});

  @override
  ConsumerState<AddReturnScreen> createState() => _AddReturnScreenState();
}

class _AddReturnScreenState extends ConsumerState<AddReturnScreen> {
  final _notesCtrl = TextEditingController();
  final List<_InvoiceRow> _rows = [];
  DateTime _selectedDate = DateTime.now();

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
    setState(() => _rows.add(_InvoiceRow(product: product)));
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
    }

    final items = _rows.map((row) {
      final qty = double.parse(row.qtyCtrl.text);
      final price =
          double.tryParse(row.priceCtrl.text) ?? row.product.salePriceUsd;
      return InvoiceItemDetail(
        item: CustomerInvoiceItem(
            id: 0,
            invoiceId: 0,
            productId: row.product.id,
            quantity: qty,
            unitPriceUsd: price,
            productNameSnapshot: row.product.name),
        product: row.product,
      );
    }).toList();

    await ref.read(customerActionsProvider).addReturnWithItems(
          customerId: widget.customer.id,
          items: items,
          notes: _notesCtrl.text.trim(),
          date: _selectedDate,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فاتورة مرتجعة - ${widget.customer.name}'),
        backgroundColor: Colors.deepOrange,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('حفظ',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: Colors.deepOrange.withOpacity(0.08),
          child: const Text(
            'سيُعاد إدراج الكميات المختارة إلى المخزون تلقائياً، ويُخصم '
            'مبلغ المرتجع من رصيد الزبون المستحق.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _DateTile(date: _selectedDate, onTap: _pickDate),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إضافة منتج للمرتجع'),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _ProductPickerSheet(
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
                        child: Text('لم تُضف أي منتجات بعد',
                            style: TextStyle(color: Colors.grey))))
              else
                ..._rows.asMap().entries.map((e) => _InvoiceItemCard(
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
                    labelText: 'سبب الإرجاع (اختياري)',
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        _TotalBar(total: _total),
      ]),
    );
  }
}

// ============================================================
// ADD PAYMENT
// ============================================================
class AddPaymentScreen extends ConsumerStatefulWidget {
  final Customer customer;
  const AddPaymentScreen({super.key, required this.customer});

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(customerActionsProvider).addPayment(
          customerId: widget.customer.id,
          amountUsd: double.parse(_amountCtrl.text),
          notes: _notesCtrl.text.trim(),
          date: _selectedDate,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync =
        ref.watch(customerBalanceProvider(widget.customer.id));
    return Scaffold(
      appBar:
          AppBar(title: Text('دفعة جديدة - ${widget.customer.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            balanceAsync.when(
              data: (b) => Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المستحق حالياً:'),
                    CurrencyDisplay(amountUsd: b, showBoth: false),
                  ],
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'مبلغ الدفعة (\$)',
                  border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى إدخال المبلغ';
                if (double.tryParse(v) == null) return 'قيمة غير صحيحة';
                if (double.parse(v) <= 0)
                  return 'يجب أن يكون المبلغ أكبر من صفر';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            _DateTile(
                date: _selectedDate,
                onTap: () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100));
                  if (picked != null)
                    setState(() => _selectedDate = picked);
                }),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('إضافة الدفعة'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SHARED WIDGETS (invoice helpers)
// ============================================================
class _DateTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _DateTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      leading: const Icon(Icons.calendar_today),
      title: Text('التاريخ: ${DateFormat('yyyy/MM/dd').format(date)}'),
      trailing: const Icon(Icons.edit),
      onTap: onTap,
    );
  }
}

class _TotalBar extends ConsumerWidget {
  final double total;
  const _TotalBar({required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('الإجمالي:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          CurrencyDisplay(
            amountUsd: total,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal),
          ),
        ],
      ),
    );
  }
}

class _InvoiceItemCard extends StatelessWidget {
  final _InvoiceRow row;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _InvoiceItemCard(
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
            Text('المتوفر: ${row.product.quantity} ${row.product.unit}',
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

class _ProductPickerSheet extends ConsumerStatefulWidget {
  final Function(Product) onSelect;
  final List<int> excludeIds;
  const _ProductPickerSheet(
      {required this.onSelect, required this.excludeIds});

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
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
                        : p.name
                            .toLowerCase()
                            .contains(_query.toLowerCase()))
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

class _InvoiceRow {
  final Product product;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _InvoiceRow({required this.product, String? initialQty, String? initialPrice})
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
