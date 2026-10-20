import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/database/app_database.dart';
import '../../../providers/all_providers.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? product;
  const AddEditProductScreen({super.key, this.product});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _purchaseCtrl;
  late TextEditingController _saleCtrl;
  late String _category;
  late String _unit;
  bool _priceInSyp = false;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _qtyCtrl = TextEditingController(text: p != null ? p.quantity.toString() : '');
    _purchaseCtrl = TextEditingController(
        text: p != null ? p.purchasePriceUsd.toString() : '');
    _saleCtrl =
        TextEditingController(text: p != null ? p.salePriceUsd.toString() : '');
    _category = p?.category ?? AppConstants.productCategories.first;
    _unit = p?.unit ?? AppConstants.productUnits.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _purchaseCtrl.dispose();
    _saleCtrl.dispose();
    super.dispose();
  }

  String? _required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? 'يرجى إدخال $field' : null;

  String? _number(String? v, String field) {
    if (v == null || v.trim().isEmpty) return 'يرجى إدخال $field';
    if (double.tryParse(v) == null) return 'يرجى إدخال رقم صحيح';
    if (double.parse(v) < 0) return 'لا يمكن أن تكون القيمة سالبة';
    return null;
  }

  /// يحوّل محتوى الحقلين (شراء/بيع) بين الدولار والليرة عند تبديل
  /// عملة الإدخال، حتى يبقى الرقم المعروض صحيحاً دائماً.
  void _toggleCurrency(bool toSyp, double rate) {
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('يرجى تعيين سعر الصرف من الإعدادات أولاً')));
      return;
    }
    setState(() {
      for (final ctrl in [_purchaseCtrl, _saleCtrl]) {
        final current = double.tryParse(ctrl.text);
        if (current == null) continue;
        final converted = toSyp ? current * rate : current / rate;
        ctrl.text = _trimZeros(converted);
      }
      _priceInSyp = toSyp;
    });
  }

  String _trimZeros(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  /// يحوّل قيمة حقل إلى دولار (كما تُخزَّن دائماً) بحسب عملة الإدخال
  /// الحالية.
  double _toUsd(String text, double rate) {
    final v = double.parse(text);
    return _priceInSyp && rate > 0 ? v / rate : v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final rate = ref.read(currentExchangeRateProvider).valueOrNull ?? 0;
    final purchaseUsd = _toUsd(_purchaseCtrl.text, rate);
    final saleUsd = _toUsd(_saleCtrl.text, rate);
    final actions = ref.read(productActionsProvider);
    bool success;

    if (isEditing) {
      success = await actions.updateProduct(widget.product!.copyWith(
        name: _nameCtrl.text.trim(),
        category: _category,
        quantity: double.parse(_qtyCtrl.text),
        unit: _unit,
        purchasePriceUsd: purchaseUsd,
        salePriceUsd: saleUsd,
        updatedAt: DateTime.now(),
      ));
    } else {
      success = await actions.addProduct(
        name: _nameCtrl.text.trim(),
        category: _category,
        quantity: double.parse(_qtyCtrl.text),
        unit: _unit,
        purchasePriceUsd: purchaseUsd,
        salePriceUsd: saleUsd,
      );
    }

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      final archived = await ref
          .read(productRepositoryProvider)
          .findArchivedDuplicate(_nameCtrl.text.trim(), _category);
      if (!mounted) return;
      if (archived != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('المنتج موجود بالأرشيف'),
            content: Text(
                'يوجد منتج بنفس الاسم "${archived.name}" والفئة مؤرشف مسبقاً. '
                'يمكنك استعادته من الأرشيف بدل إنشاء منتج جديد.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(productActionsProvider)
                      .unarchiveProduct(archived.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('استعادة من الأرشيف'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('❌ يوجد منتج بنفس الاسم والفئة مسبقاً'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rateAsync = ref.watch(currentExchangeRateProvider);
    final rate = rateAsync.valueOrNull ?? 0;
    final currencyLabel = _priceInSyp ? 'ل.س' : '\$';

    return Scaffold(
      appBar: AppBar(
          title: Text(isEditing ? 'تعديل منتج' : 'إضافة منتج جديد')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'اسم المنتج', border: OutlineInputBorder()),
              validator: (v) => _required(v, 'اسم المنتج'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                  labelText: 'الفئة', border: OutlineInputBorder()),
              items: AppConstants.productCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'الكمية', border: OutlineInputBorder()),
                  validator: (v) => _number(v, 'الكمية'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: const InputDecoration(
                      labelText: 'الوحدة', border: OutlineInputBorder()),
                  items: AppConstants.productUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v!),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ===== تبديل عملة إدخال السعر =====
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إدخال الأسعار بالليرة السورية'),
                subtitle: Text(rate > 0
                    ? 'الأسعار تُخزَّن دائماً بالدولار (سعر الصرف: ${rate.toStringAsFixed(0)})'
                    : 'يرجى تعيين سعر الصرف من الإعدادات أولاً',
                    style: const TextStyle(fontSize: 11)),
                value: _priceInSyp,
                onChanged: (v) => _toggleCurrency(v, rate),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _purchaseCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'سعر الشراء ($currencyLabel)',
                  border: const OutlineInputBorder()),
              validator: (v) => _number(v, 'سعر الشراء'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _saleCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'سعر البيع ($currencyLabel)',
                  border: const OutlineInputBorder()),
              validator: (v) => _number(v, 'سعر البيع'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              child: Text(isEditing ? 'حفظ التعديلات' : 'إضافة المنتج'),
            ),
          ],
        ),
      ),
    );
  }
}
