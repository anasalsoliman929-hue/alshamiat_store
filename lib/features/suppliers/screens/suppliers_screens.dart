import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/invoice_with_items.dart';
import '../../../core/services/pdf_invoice_service.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/all_providers.dart';
import '../../../shared/widgets/currency_display.dart';
import 'add_purchase_invoice_screen.dart';
import 'edit_purchase_invoice_screen.dart';

class SuppliersListScreen extends ConsumerWidget {
  const SuppliersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الموردين')),
      body: suppliersAsync.when(
        data: (suppliers) => suppliers.isEmpty
            ? const Center(child: Text('لا يوجد موردين حالياً'))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: suppliers.length,
                itemBuilder: (_, i) =>
                    _SupplierCard(supplier: suppliers[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "SuppliersListScreen",
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => const AddEditSupplierScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SupplierCard extends ConsumerWidget {
  final Supplier supplier;
  const _SupplierCard({required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(supplierBalanceProvider(supplier.id));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) =>
                    SupplierDetailsScreen(supplier: supplier))),
        leading: const CircleAvatar(child: Icon(Icons.store)),
        title: Text(supplier.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: supplier.phone.isNotEmpty ? Text(supplier.phone) : null,
        trailing: balanceAsync.when(
          data: (balance) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('مستحق له',
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

class AddEditSupplierScreen extends ConsumerStatefulWidget {
  final Supplier? supplier;
  const AddEditSupplierScreen({super.key, this.supplier});

  @override
  ConsumerState<AddEditSupplierScreen> createState() =>
      _AddEditSupplierScreenState();
}

class _AddEditSupplierScreenState
    extends ConsumerState<AddEditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _notesCtrl;

  bool get isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
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
    final actions = ref.read(supplierActionsProvider);
    if (isEditing) {
      await actions.updateSupplier(widget.supplier!.copyWith(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ));
    } else {
      await actions.addSupplier(
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
      appBar: AppBar(
          title: Text(isEditing ? 'تعديل مورد' : 'إضافة مورد جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم المورد / الشركة',
                  border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'يرجى إدخال الاسم'
                  : null,
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
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة المورد'),
            ),
          ],
        ),
      ),
    );
  }
}

class SupplierDetailsScreen extends ConsumerWidget {
  final Supplier supplier;
  const SupplierDetailsScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(supplierBalanceProvider(supplier.id));
    final paymentsAsync = ref.watch(supplierPaymentsProvider(supplier.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'كشف حساب',
            onPressed: () => exportSupplierStatementPdf(context, ref, supplier),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) =>
                        AddEditSupplierScreen(supplier: supplier))),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: Column(children: [
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
              const Text('المبلغ المستحق له',
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

        if (supplier.phone.isNotEmpty || supplier.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              if (supplier.phone.isNotEmpty)
                Text('الهاتف: ${supplier.phone}'),
              if (supplier.notes.isNotEmpty)
                Text('ملاحظات: ${supplier.notes}'),
              const SizedBox(height: 8),
            ]),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long),
                label: const Text('فاتورة شراء'),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddPurchaseInvoiceScreen(supplier: supplier))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payments),
                label: const Text('تسديد دفعة'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddSupplierPaymentScreen(supplier: supplier))),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(children: [
              const TabBar(
                labelColor: Colors.teal,
                tabs: [
                  Tab(text: 'فواتير الشراء'),
                  Tab(text: 'الدفعات')
                ],
              ),
              Expanded(
                child: TabBarView(children: [
                  _PurchaseInvoicesList(supplier: supplier),
                  _SupplierPaymentsList(
                      paymentsAsync: paymentsAsync, ref: ref),
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
            Text('سيتم حذف "${supplier.name}" مع جميع فواتيره ودفعاته.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              ref.read(supplierActionsProvider).deleteSupplier(supplier.id);
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

class _PurchaseInvoicesList extends ConsumerWidget {
  final Supplier supplier;
  const _PurchaseInvoicesList({required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierId = supplier.id;
    final invoicesAsync = ref.watch(supplierInvoicesWithItemsProvider(supplierId));
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm');

    return invoicesAsync.when(
      data: (invoices) => invoices.isEmpty
          ? const Center(child: Text('لا توجد فواتير شراء'))
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
                          onPressed: () => exportPurchaseInvoicePdf(
                              context, ref, inv, supplier),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blue, size: 20),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => EditPurchaseInvoiceScreen(
                                        invoiceWithItems: inv,
                                        supplierId: supplierId,
                                      ))),
                        ),
                      ],
                    ),
                    children: [
                      ...inv.items.map((d) => ListTile(
                            dense: true,
                            title: Text(d.productName),
                            subtitle: Text(
                                '${d.item.quantity} × \$${d.item.unitPurchasePriceUsd.toStringAsFixed(2)}'),
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

/// يبني ويعرض فاتورة شراء PDF قابلة للمعاينة/الطباعة/المشاركة
/// يبني ويعرض كشف حساب كامل للمورد (كل الفواتير والدفعات) PDF
Future<void> exportSupplierStatementPdf(
    BuildContext context, WidgetRef ref, Supplier supplier) async {
  try {
    final service = PdfInvoiceService();
    final bytes = await runWithPdfLoadingDialog(context, () async {
      final repo = ref.read(supplierRepositoryProvider);
      final invoices = await repo.getAllInvoicesWithItemsForSupplier(supplier.id);
      final payments = await repo.getAllPaymentsForSupplier(supplier.id);
      final rate = await ref.read(currentExchangeRateProvider.future);
      return service.buildSupplierStatementPdf(
        supplierName: supplier.name,
        supplierPhone: supplier.phone,
        invoices: invoices,
        payments: payments,
        exchangeRate: rate,
      );
    });
    await service.previewAndPrint(bytes, 'كشف_حساب_${supplier.name}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر إنشاء كشف الحساب: $e')));
    }
  }
}

Future<void> exportPurchaseInvoicePdf(BuildContext context, WidgetRef ref,
    SupplierInvoiceWithItems inv, Supplier supplier) async {
  try {
    final service = PdfInvoiceService();
    final bytes = await runWithPdfLoadingDialog(context, () async {
      final rate = await ref.read(currentExchangeRateProvider.future);
      return service.buildPurchaseInvoicePdf(
        invoice: inv,
        supplierName: supplier.name,
        supplierPhone: supplier.phone,
        exchangeRate: rate,
      );
    });
    await service.previewAndPrint(bytes, 'فاتورة_شراء_${inv.invoice.id}');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذّر إنشاء PDF: $e')));
    }
  }
}

class _SupplierPaymentsList extends StatelessWidget {
  final AsyncValue<List<SupplierPayment>> paymentsAsync;
  final WidgetRef ref;
  const _SupplierPaymentsList(
      {required this.paymentsAsync, required this.ref});

  @override
  Widget build(BuildContext context) {
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
                    title: CurrencyDisplay(
                        amountUsd: p.amountUsd, showBoth: false),
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
      BuildContext context, WidgetRef ref, SupplierPayment payment) {
    final amountCtrl =
        TextEditingController(text: payment.amountUsd.toString());
    final notesCtrl = TextEditingController(text: payment.notes);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الدفعة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) return;
              await ref.read(supplierActionsProvider).updatePayment(
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

class AddSupplierPaymentScreen extends ConsumerStatefulWidget {
  final Supplier supplier;
  const AddSupplierPaymentScreen({super.key, required this.supplier});

  @override
  ConsumerState<AddSupplierPaymentScreen> createState() =>
      _AddSupplierPaymentScreenState();
}

class _AddSupplierPaymentScreenState
    extends ConsumerState<AddSupplierPaymentScreen> {
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
    await ref.read(supplierActionsProvider).addPayment(
          supplierId: widget.supplier.id,
          amountUsd: double.parse(_amountCtrl.text),
          notes: _notesCtrl.text.trim(),
          date: _selectedDate,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync =
        ref.watch(supplierBalanceProvider(widget.supplier.id));
    return Scaffold(
      appBar:
          AppBar(title: Text('تسديد دفعة - ${widget.supplier.name}')),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
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
                  const Text('المستحق له حالياً:'),
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
              if (double.parse(v) <= 0) return 'يجب أن يكون أكبر من صفر';
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
          ListTile(
            tileColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            leading: const Icon(Icons.calendar_today),
            title: Text(
                'التاريخ: ${DateFormat('yyyy/MM/dd').format(_selectedDate)}'),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100));
              if (picked != null) setState(() => _selectedDate = picked);
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تسديد الدفعة'),
          ),
        ]),
      ),
    );
  }
}
