import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/database/app_database.dart';
import '../../providers/all_providers.dart';
import '../../shared/widgets/currency_display.dart';

class ExpensesLossesScreen extends StatelessWidget {
  const ExpensesLossesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المصاريف والخسائر'),
          bottom: const TabBar(tabs: [
            Tab(text: 'المصاريف الشخصية'),
            Tab(text: 'خسائر المنتجات'),
          ]),
        ),
        body: const TabBarView(children: [
          _ExpensesTab(),
          _LossesTab(),
        ]),
      ),
    );
  }
}

// ============================================================
// المصاريف الشخصية
// ============================================================
class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(personalExpensesStreamProvider);
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm');

    return Scaffold(
      body: expensesAsync.when(
        data: (expenses) {
          final total = expenses.fold<double>(0, (s, e) => s + e.amountUsd);
          return Column(children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي المصاريف',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  CurrencyDisplay(
                      amountUsd: total,
                      showBoth: false,
                      style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: expenses.isEmpty
                  ? const Center(child: Text('لا توجد مصاريف مسجّلة'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: expenses.length,
                      itemBuilder: (_, i) {
                        final e = expenses[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Icon(Icons.money_off, color: Colors.white, size: 18),
                            ),
                            title: Text(e.description),
                            subtitle: Text(
                                '${e.category} • ${dateFormat.format(e.date)}'
                                '${e.notes.isNotEmpty ? '\n${e.notes}' : ''}'),
                            isThreeLine: e.notes.isNotEmpty,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CurrencyDisplay(
                                    amountUsd: e.amountUsd,
                                    showBoth: false,
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.grey, size: 20),
                                  onPressed: () => _confirmDeleteExpense(
                                      context, ref, e.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('مصروف جديد'),
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المصروف'),
        content: const Text('هل تريد حذف هذا المصروف؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await ref.read(expenseActionsProvider).deleteExpense(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = 'عام';
    const categories = ['عام', 'إيجار', 'كهرباء وماء', 'نقل', 'صيانة', 'رواتب', 'أخرى'];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('مصروف شخصي جديد'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'الوصف', border: OutlineInputBorder()),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'أدخل الوصف' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(
                      labelText: 'التصنيف', border: OutlineInputBorder()),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v ?? 'عام'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'المبلغ (\$)', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'أدخل المبلغ';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'قيمة غير صحيحة';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'ملاحظات (اختياري)',
                      border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                await ref.read(expenseActionsProvider).addExpense(
                      description: descCtrl.text.trim(),
                      amountUsd: double.parse(amountCtrl.text),
                      category: category,
                      notes: notesCtrl.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// خسائر المنتجات
// ============================================================
class _LossesTab extends ConsumerWidget {
  const _LossesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lossesAsync = ref.watch(productLossesStreamProvider);
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm');

    return Scaffold(
      body: lossesAsync.when(
        data: (losses) {
          final total = losses.fold<double>(0, (s, l) => s + l.estimatedValueUsd);
          return Column(children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي قيمة الخسائر',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  CurrencyDisplay(
                      amountUsd: total,
                      showBoth: false,
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: losses.isEmpty
                  ? const Center(child: Text('لا توجد خسائر مسجّلة'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: losses.length,
                      itemBuilder: (_, i) {
                        final l = losses[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.white, size: 18),
                            ),
                            title: Text(l.productNameSnapshot),
                            subtitle: Text(
                                'الكمية: ${_fmtQty(l.quantity)} • ${dateFormat.format(l.date)}'
                                '${l.reason.isNotEmpty ? '\nالسبب: ${l.reason}' : ''}'),
                            isThreeLine: l.reason.isNotEmpty,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CurrencyDisplay(
                                    amountUsd: l.estimatedValueUsd,
                                    showBoth: false,
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.grey, size: 20),
                                  onPressed: () =>
                                      _confirmDeleteLoss(context, ref, l.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddLossDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('تسجيل خسارة'),
      ),
    );
  }

  String _fmtQty(double q) => q % 1 == 0 ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  void _confirmDeleteLoss(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف سجل الخسارة'),
        content: const Text('سيتم إرجاع الكمية إلى المخزون. هل تريد الحذف؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              await ref.read(expenseActionsProvider).deleteLoss(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddLossDialog(BuildContext context, WidgetRef ref) {
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    int? selectedProductId;
    String selectedProductName = '';
    String selectedProductUnit = '';
    double selectedProductQuantity = 0;
    final formKey = GlobalKey<FormState>();
    const reasons = ['تلف', 'انتهاء صلاحية', 'كسر', 'فقدان/سرقة', 'أخرى'];
    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('تسجيل خسارة منتج'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                InkWell(
                  onTap: () async {
                    final picked = await _pickProduct(context, ref);
                    if (picked != null) {
                      setState(() {
                        selectedProductId = picked.id;
                        selectedProductName = picked.name;
                        selectedProductUnit = picked.unit;
                        selectedProductQuantity = picked.quantity;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'المنتج',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                    child: Text(
                      selectedProductId == null
                          ? 'اضغط لاختيار منتج'
                          : '$selectedProductName (متوفر: ${_fmtQty(selectedProductQuantity)} $selectedProductUnit)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectedProductId == null
                            ? Colors.grey
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'الكمية المفقودة'
                          '${selectedProductId != null ? ' ($selectedProductUnit)' : ''}',
                      border: const OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'أدخل الكمية';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'قيمة غير صحيحة';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: const InputDecoration(
                      labelText: 'السبب', border: OutlineInputBorder()),
                  items: reasons
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => selectedReason = v ?? reasons.first),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                      labelText: 'تفاصيل إضافية (اختياري)',
                      border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                if (selectedProductId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('اختر منتجاً أولاً')));
                  return;
                }
                if (!formKey.currentState!.validate()) return;
                final qty = double.parse(qtyCtrl.text);

                // إعادة قراءة الكمية الفعلية الحالية (وقت الحفظ) لتفادي
                // أي بيانات قديمة محفوظة أثناء فتح النافذة.
                final freshProducts = await ref
                    .read(productRepositoryProvider)
                    .watchActiveProducts()
                    .first;
                Product? freshProduct;
                for (final p in freshProducts) {
                  if (p.id == selectedProductId) {
                    freshProduct = p;
                    break;
                  }
                }
                final availableQty =
                    freshProduct?.quantity ?? selectedProductQuantity;

                if (qty > availableQty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('الكمية أكبر من المتوفر بالمخزون')));
                  return;
                }
                final extra = reasonCtrl.text.trim();
                final reason = extra.isEmpty
                    ? selectedReason
                    : '$selectedReason - $extra';
                await ref.read(expenseActionsProvider).addLoss(
                      productId: selectedProductId,
                      quantity: qty,
                      reason: reason,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  /// نافذة سفلية لاختيار منتج بالبحث — بديل عن قائمة منسدلة طويلة،
  /// ولا تحتفظ بأي كائن Product عبر إعادة البناء (يتجنب مشاكل عدم
  /// تطابق القيم عند تحديث بيانات المنتج من التدفق الحي).
  Future<Product?> _pickProduct(BuildContext context, WidgetRef ref) {
    final searchCtrl = TextEditingController();
    return showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Consumer(
              builder: (sheetCtx, sheetRef, _) {
                final productsAsync = sheetRef.watch(productsStreamProvider);
                return StatefulBuilder(
                  builder: (sheetCtx, setSheetState) {
                    String query = '';
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
                          left: 16,
                          right: 16,
                          top: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          TextField(
                            controller: searchCtrl,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'ابحث عن منتج',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) =>
                                setSheetState(() => query = v.trim()),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: productsAsync.when(
                              data: (products) {
                                final filtered = query.isEmpty
                                    ? products
                                    : products
                                        .where((p) => p.name
                                            .toLowerCase()
                                            .contains(query.toLowerCase()))
                                        .toList();
                                if (filtered.isEmpty) {
                                  return const Center(
                                      child: Text('لا توجد نتائج'));
                                }
                                return ListView.builder(
                                  controller: scrollController,
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final p = filtered[i];
                                    return ListTile(
                                      title: Text(p.name),
                                      subtitle: Text(
                                          'متوفر: ${_fmtQty(p.quantity)} ${p.unit}'),
                                      onTap: () =>
                                          Navigator.pop(sheetCtx, p),
                                    );
                                  },
                                );
                              },
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (e, _) => Center(child: Text('خطأ: $e')),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
