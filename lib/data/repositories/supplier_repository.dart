import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/invoice_with_items.dart';

class SupplierRepository {
  final AppDatabase db;
  SupplierRepository(this.db);

  Future<int> addSupplier(SuppliersCompanion s) => db.into(db.suppliers).insert(s);
  Future<bool> updateSupplier(Supplier s) => db.update(db.suppliers).replace(s);
  Future<int> deleteSupplier(int id) =>
      (db.delete(db.suppliers)..where((s) => s.id.equals(id))).go();
  Stream<List<Supplier>> watchAllSuppliers() => db.select(db.suppliers).watch();

  Stream<List<SupplierInvoice>> watchInvoicesForSupplier(int supplierId) =>
      (db.select(db.supplierInvoices)
            ..where((i) => i.supplierId.equals(supplierId))
            ..orderBy([(i) => OrderingTerm.desc(i.date)]))
          .watch();

  Future<int> addPayment(SupplierPaymentsCompanion p) =>
      db.into(db.supplierPayments).insert(p);
  Future<bool> updatePayment(SupplierPayment p) =>
      db.update(db.supplierPayments).replace(p);
  Future<int> deletePayment(int id) =>
      (db.delete(db.supplierPayments)..where((p) => p.id.equals(id))).go();
  Stream<List<SupplierPayment>> watchPaymentsForSupplier(int supplierId) =>
      (db.select(db.supplierPayments)
            ..where((p) => p.supplierId.equals(supplierId))
            ..orderBy([(p) => OrderingTerm.desc(p.date)]))
          .watch();

  Future<double> getSupplierBalance(int supplierId) async {
    final invoicesTotal = db.supplierInvoices.totalAmountUsd.sum();
    final paymentsTotal = db.supplierPayments.amountUsd.sum();

    final invQuery = db.selectOnly(db.supplierInvoices)
      ..addColumns([invoicesTotal])
      ..where(db.supplierInvoices.supplierId.equals(supplierId));
    final payQuery = db.selectOnly(db.supplierPayments)
      ..addColumns([paymentsTotal])
      ..where(db.supplierPayments.supplierId.equals(supplierId));

    final invRow = await invQuery.getSingle();
    final payRow = await payQuery.getSingle();
    return (invRow.read(invoicesTotal) ?? 0) - (payRow.read(paymentsTotal) ?? 0);
  }

  Future<Supplier?> getSupplierById(int id) =>
      (db.select(db.suppliers)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// كل فواتير المورد كاملة (مرتبة تصاعدياً) — لكشف الحساب
  Future<List<SupplierInvoiceWithItems>> getAllInvoicesWithItemsForSupplier(
      int supplierId) async {
    final invoices = await (db.select(db.supplierInvoices)
          ..where((i) => i.supplierId.equals(supplierId))
          ..orderBy([(i) => OrderingTerm.asc(i.date)]))
        .get();
    final result = <SupplierInvoiceWithItems>[];
    for (final inv in invoices) {
      final withItems = await getInvoiceWithItems(inv.id);
      if (withItems != null) result.add(withItems);
    }
    return result;
  }

  /// كل دفعات المورد كاملة (مرتبة تصاعدياً) — لكشف الحساب
  Future<List<SupplierPayment>> getAllPaymentsForSupplier(int supplierId) =>
      (db.select(db.supplierPayments)
            ..where((p) => p.supplierId.equals(supplierId))
            ..orderBy([(p) => OrderingTerm.asc(p.date)]))
          .get();

  Future<List<SupplierInvoice>> getInvoicesBetween(DateTime start, DateTime end) =>
      (db.select(db.supplierInvoices)
            ..where((i) =>
                i.date.isBiggerOrEqualValue(start) & i.date.isSmallerThanValue(end)))
          .get();
  Future<List<SupplierPayment>> getPaymentsBetween(DateTime start, DateTime end) =>
      (db.select(db.supplierPayments)
            ..where((p) =>
                p.date.isBiggerOrEqualValue(start) & p.date.isSmallerThanValue(end)))
          .get();

  Future<double> getTotalPayables() async {
    final suppliers = await db.select(db.suppliers).get();
    double total = 0;
    for (final s in suppliers) total += await getSupplierBalance(s.id);
    return total;
  }

  // ============================================================
  // فواتير الشراء مع العناصر: منتج موجود -> تُضاف الكمية له،
  // منتج جديد -> يُنشأ بمعلوماته وكميته وسعره
  // ============================================================
  Future<void> addPurchaseInvoiceWithItems({
    required int supplierId,
    required List<PurchaseLineInput> lines,
    String notes = '',
    DateTime? date,
  }) async {
    if (lines.isEmpty) throw Exception('الفاتورة لا يمكن أن تكون فارغة');

    await db.transaction(() async {
      final resolved = <_ResolvedLine>[];
      double total = 0;

      for (final line in lines) {
        int productId;
        String productName;
        String unit;

        if (line.productId != null) {
          // منتج موجود: تُضاف الكمية الجديدة وتُحدَّث آخر سعر شراء
          final product = await (db.select(db.products)
                ..where((p) => p.id.equals(line.productId!)))
              .getSingle();
          await (db.update(db.products)..where((p) => p.id.equals(product.id)))
              .write(ProductsCompanion(
            quantity: Value(product.quantity + line.quantity),
            purchasePriceUsd: Value(line.unitPurchasePriceUsd),
            updatedAt: Value(DateTime.now()),
          ));
          productId = product.id;
          productName = product.name;
          unit = product.unit;
        } else {
          // منتج جديد: يُنشأ بمعلوماته وكميته وسعره
          final draft = line.draft!;
          productId = await db.into(db.products).insert(
                ProductsCompanion.insert(
                  name: draft.name,
                  category: draft.category,
                  quantity: line.quantity,
                  unit: Value(draft.unit),
                  purchasePriceUsd: line.unitPurchasePriceUsd,
                  salePriceUsd: draft.salePriceUsd,
                ),
              );
          productName = draft.name;
          unit = draft.unit;
        }

        resolved.add(_ResolvedLine(
          productId: productId,
          productName: productName,
          unit: unit,
          quantity: line.quantity,
          unitPurchasePriceUsd: line.unitPurchasePriceUsd,
        ));
        total += line.quantity * line.unitPurchasePriceUsd;
      }

      final invoiceId = await db.into(db.supplierInvoices).insert(
            SupplierInvoicesCompanion.insert(
              supplierId: supplierId,
              totalAmountUsd: total,
              productsDescription: Value(_describeLines(resolved)),
              notes: Value(notes),
              date: date != null ? Value(date) : const Value.absent(),
            ),
          );

      for (final r in resolved) {
        await db.into(db.supplierInvoiceItems).insert(
              SupplierInvoiceItemsCompanion.insert(
                invoiceId: invoiceId,
                productId: Value(r.productId),
                quantity: r.quantity,
                unitPurchasePriceUsd: r.unitPurchasePriceUsd,
                productNameSnapshot: Value(r.productName),
              ),
            );
      }
    });
  }

  Future<void> updatePurchaseInvoiceWithItems({
    required int invoiceId,
    required int supplierId,
    required List<PurchaseLineInput> newLines,
    String notes = '',
    DateTime? date,
  }) async {
    if (newLines.isEmpty) throw Exception('الفاتورة لا يمكن أن تكون فارغة');

    await db.transaction(() async {
      // 1. إرجاع أثر الكميات القديمة (طرح ما أُضيف سابقاً على المخزون)
      final oldItems = await (db.select(db.supplierInvoiceItems)
            ..where((i) => i.invoiceId.equals(invoiceId)))
          .get();

      for (final oldItem in oldItems) {
        if (oldItem.productId != null) {
          final product = await (db.select(db.products)
                ..where((p) => p.id.equals(oldItem.productId!)))
              .getSingleOrNull();
          if (product != null) {
            final restored = product.quantity - oldItem.quantity;
            await (db.update(db.products)
                  ..where((p) => p.id.equals(oldItem.productId!)))
                .write(ProductsCompanion(
              quantity: Value(restored < 0 ? 0 : restored),
              updatedAt: Value(DateTime.now()),
            ));
          }
        }
      }

      // 2. حذف العناصر القديمة
      await (db.delete(db.supplierInvoiceItems)
            ..where((i) => i.invoiceId.equals(invoiceId)))
          .go();

      // 3. تطبيق العناصر الجديدة (إضافة الكميات، وإنشاء أي منتج جديد)
      final resolved = <_ResolvedLine>[];
      double total = 0;

      for (final line in newLines) {
        int productId;
        String productName;
        String unit;

        if (line.productId != null) {
          final product = await (db.select(db.products)
                ..where((p) => p.id.equals(line.productId!)))
              .getSingle();
          await (db.update(db.products)..where((p) => p.id.equals(product.id)))
              .write(ProductsCompanion(
            quantity: Value(product.quantity + line.quantity),
            purchasePriceUsd: Value(line.unitPurchasePriceUsd),
            updatedAt: Value(DateTime.now()),
          ));
          productId = product.id;
          productName = product.name;
          unit = product.unit;
        } else {
          final draft = line.draft!;
          productId = await db.into(db.products).insert(
                ProductsCompanion.insert(
                  name: draft.name,
                  category: draft.category,
                  quantity: line.quantity,
                  unit: Value(draft.unit),
                  purchasePriceUsd: line.unitPurchasePriceUsd,
                  salePriceUsd: draft.salePriceUsd,
                ),
              );
          productName = draft.name;
          unit = draft.unit;
        }

        resolved.add(_ResolvedLine(
          productId: productId,
          productName: productName,
          unit: unit,
          quantity: line.quantity,
          unitPurchasePriceUsd: line.unitPurchasePriceUsd,
        ));
        total += line.quantity * line.unitPurchasePriceUsd;
      }

      // 4. تحديث الفاتورة نفسها
      await (db.update(db.supplierInvoices)..where((i) => i.id.equals(invoiceId)))
          .write(SupplierInvoicesCompanion(
        totalAmountUsd: Value(total),
        productsDescription: Value(_describeLines(resolved)),
        notes: Value(notes),
        date: date != null ? Value(date) : const Value.absent(),
      ));

      // 5. إدراج العناصر الجديدة
      for (final r in resolved) {
        await db.into(db.supplierInvoiceItems).insert(
              SupplierInvoiceItemsCompanion.insert(
                invoiceId: invoiceId,
                productId: Value(r.productId),
                quantity: r.quantity,
                unitPurchasePriceUsd: r.unitPurchasePriceUsd,
                productNameSnapshot: Value(r.productName),
              ),
            );
      }
    });
  }

  String _describeLines(List<_ResolvedLine> lines) => lines
      .map((l) => '${l.quantity.toStringAsFixed(l.quantity % 1 == 0 ? 0 : 2)} '
          '${l.unit} ${l.productName}')
      .join('، ');

  Future<SupplierInvoiceWithItems?> getInvoiceWithItems(int invoiceId) async {
    final invoice = await (db.select(db.supplierInvoices)
          ..where((i) => i.id.equals(invoiceId)))
        .getSingleOrNull();
    if (invoice == null) return null;

    final items = await (db.select(db.supplierInvoiceItems)
          ..where((i) => i.invoiceId.equals(invoiceId)))
        .get();

    final details = <SupplierInvoiceItemDetail>[];
    for (final item in items) {
      Product? product;
      if (item.productId != null) {
        product = await (db.select(db.products)
              ..where((p) => p.id.equals(item.productId!)))
            .getSingleOrNull();
      }
      details.add(SupplierInvoiceItemDetail(item: item, product: product));
    }
    return SupplierInvoiceWithItems(invoice: invoice, items: details);
  }

  Stream<List<SupplierInvoiceWithItems>> watchInvoicesWithItemsForSupplier(
      int supplierId) async* {
    yield* db.supplierInvoices.select().watch().asyncMap((_) async {
      final invoices = await (db.select(db.supplierInvoices)
            ..where((i) => i.supplierId.equals(supplierId))
            ..orderBy([(i) => OrderingTerm.desc(i.date)]))
          .get();

      final result = <SupplierInvoiceWithItems>[];
      for (final invoice in invoices) {
        final withItems = await getInvoiceWithItems(invoice.id);
        if (withItems != null) result.add(withItems);
      }
      return result;
    });
  }

  Future<List<SupplierInvoiceWithItems>> getInvoiceWithItemsListBetween(
      DateTime start, DateTime end) async {
    final invoices = await getInvoicesBetween(start, end);
    final result = <SupplierInvoiceWithItems>[];
    for (final invoice in invoices) {
      final withItems = await getInvoiceWithItems(invoice.id);
      if (withItems != null) result.add(withItems);
    }
    return result;
  }
}

class _ResolvedLine {
  final int productId;
  final String productName;
  final String unit;
  final double quantity;
  final double unitPurchasePriceUsd;

  _ResolvedLine({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPurchasePriceUsd,
  });
}
