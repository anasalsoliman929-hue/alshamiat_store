import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/invoice_with_items.dart';

class CustomerRepository {
  final AppDatabase db;
  CustomerRepository(this.db);

  // ===== الزبائن =====
  Future<int> addCustomer(CustomersCompanion customer) =>
      db.into(db.customers).insert(customer);
  Future<bool> updateCustomer(Customer customer) =>
      db.update(db.customers).replace(customer);
  Future<int> deleteCustomer(int id) =>
      (db.delete(db.customers)..where((c) => c.id.equals(id))).go();
  Stream<List<Customer>> watchAllCustomers() =>
      db.select(db.customers).watch();

  // ===== الفواتير مع العناصر =====
  Future<void> addInvoiceWithItems({
    required int customerId,
    required List<InvoiceItemDetail> items,
    String notes = '',
    DateTime? date,
  }) async {
    if (items.isEmpty) throw Exception('الفاتورة لا يمكن أن تكون فارغة');
    final total = items.fold(0.0, (sum, i) => sum + i.totalUsd);

    await db.transaction(() async {
      final invoiceId = await db.into(db.customerInvoices).insert(
        CustomerInvoicesCompanion.insert(
          customerId: customerId,
          totalAmountUsd: total,
          notes: Value(notes),
          date: date != null ? Value(date) : const Value.absent(),
        ),
      );

      for (final detail in items) {
        await db.into(db.customerInvoiceItems).insert(
          CustomerInvoiceItemsCompanion.insert(
            invoiceId: invoiceId,
            productId: Value(detail.item.productId),
            quantity: detail.item.quantity,
            unitPriceUsd: detail.item.unitPriceUsd,
            productNameSnapshot: Value(detail.product?.name ?? 'منتج محذوف'),
          ),
        );
        if (detail.product != null) {
          final newQty = detail.product!.quantity - detail.item.quantity;
          await (db.update(db.products)
                ..where((p) => p.id.equals(detail.product!.id)))
              .write(ProductsCompanion(
            quantity: Value(newQty < 0 ? 0 : newQty),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }
    });
  }

  Future<void> updateInvoiceWithItems({
    required int invoiceId,
    required int customerId,
    required List<InvoiceItemDetail> newItems,
    String notes = '',
    DateTime? date,
  }) async {
    if (newItems.isEmpty) throw Exception('الفاتورة لا يمكن أن تكون فارغة');

    await db.transaction(() async {
      // 1. إرجاع الكميات القديمة
      final oldItems = await (db.select(db.customerInvoiceItems)
            ..where((i) => i.invoiceId.equals(invoiceId)))
          .get();

      for (final oldItem in oldItems) {
        if (oldItem.productId != null) {
          final product = await (db.select(db.products)
                ..where((p) => p.id.equals(oldItem.productId!)))
              .getSingleOrNull();
          if (product != null) {
            await (db.update(db.products)
                  ..where((p) => p.id.equals(oldItem.productId!)))
                .write(ProductsCompanion(
              quantity: Value(product.quantity + oldItem.quantity),
              updatedAt: Value(DateTime.now()),
            ));
          }
        }
      }

      // 2. حذف العناصر القديمة
      await (db.delete(db.customerInvoiceItems)
            ..where((i) => i.invoiceId.equals(invoiceId)))
          .go();

      // 3. تحديث الفاتورة
      final newTotal = newItems.fold(0.0, (sum, i) => sum + i.totalUsd);
      await (db.update(db.customerInvoices)
            ..where((i) => i.id.equals(invoiceId)))
          .write(CustomerInvoicesCompanion(
        totalAmountUsd: Value(newTotal),
        notes: Value(notes),
        date: date != null ? Value(date) : const Value.absent(),
      ));

      // 4. إدراج العناصر الجديدة وخصم الكميات
      for (final detail in newItems) {
        await db.into(db.customerInvoiceItems).insert(
          CustomerInvoiceItemsCompanion.insert(
            invoiceId: invoiceId,
            productId: Value(detail.item.productId),
            quantity: detail.item.quantity,
            unitPriceUsd: detail.item.unitPriceUsd,
            productNameSnapshot: Value(detail.product?.name ?? 'منتج محذوف'),
          ),
        );
        if (detail.product != null) {
          final newQty = detail.product!.quantity - detail.item.quantity;
          await (db.update(db.products)
                ..where((p) => p.id.equals(detail.product!.id)))
              .write(ProductsCompanion(
            quantity: Value(newQty < 0 ? 0 : newQty),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }
    });
  }

  Future<InvoiceWithItems?> getInvoiceWithItems(int invoiceId) async {
    final invoice = await (db.select(db.customerInvoices)
          ..where((i) => i.id.equals(invoiceId)))
        .getSingleOrNull();
    if (invoice == null) return null;

    final items = await (db.select(db.customerInvoiceItems)
          ..where((i) => i.invoiceId.equals(invoiceId)))
        .get();

    final details = <InvoiceItemDetail>[];
    for (final item in items) {
      Product? product;
      if (item.productId != null) {
        product = await (db.select(db.products)
              ..where((p) => p.id.equals(item.productId!)))
            .getSingleOrNull();
      }
      details.add(InvoiceItemDetail(item: item, product: product));
    }
    return InvoiceWithItems(invoice: invoice, items: details);
  }

  Stream<List<InvoiceWithItems>> watchInvoicesWithItemsForCustomer(
      int customerId) async* {
    yield* db.customerInvoices.select().watch().asyncMap((_) async {
      final invoices = await (db.select(db.customerInvoices)
            ..where((i) => i.customerId.equals(customerId))
            ..orderBy([(i) => OrderingTerm.desc(i.date)]))
          .get();

      final result = <InvoiceWithItems>[];
      for (final invoice in invoices) {
        final withItems = await getInvoiceWithItems(invoice.id);
        if (withItems != null) result.add(withItems);
      }
      return result;
    });
  }

  // ===== الدفعات =====
  Future<int> addPayment(CustomerPaymentsCompanion payment) =>
      db.into(db.customerPayments).insert(payment);
  Future<bool> updatePayment(CustomerPayment payment) =>
      db.update(db.customerPayments).replace(payment);
  Stream<List<CustomerPayment>> watchPaymentsForCustomer(int customerId) =>
      (db.select(db.customerPayments)
            ..where((p) => p.customerId.equals(customerId))
            ..orderBy([(p) => OrderingTerm.desc(p.date)]))
          .watch();

  // ===== الأرصدة =====
  Future<double> getCustomerBalance(int customerId) async {
    final invoicesTotal = db.customerInvoices.totalAmountUsd.sum();
    final paymentsTotal = db.customerPayments.amountUsd.sum();
    final returnsTotal = db.customerReturns.totalAmountUsd.sum();

    final invQuery = db.selectOnly(db.customerInvoices)
      ..addColumns([invoicesTotal])
      ..where(db.customerInvoices.customerId.equals(customerId));
    final payQuery = db.selectOnly(db.customerPayments)
      ..addColumns([paymentsTotal])
      ..where(db.customerPayments.customerId.equals(customerId));
    final retQuery = db.selectOnly(db.customerReturns)
      ..addColumns([returnsTotal])
      ..where(db.customerReturns.customerId.equals(customerId));

    final invRow = await invQuery.getSingle();
    final payRow = await payQuery.getSingle();
    final retRow = await retQuery.getSingle();
    return (invRow.read(invoicesTotal) ?? 0) -
        (payRow.read(paymentsTotal) ?? 0) -
        (retRow.read(returnsTotal) ?? 0);
  }

  Future<List<CustomerInvoice>> getInvoicesBetween(DateTime start, DateTime end) =>
      (db.select(db.customerInvoices)
            ..where((i) =>
                i.date.isBiggerOrEqualValue(start) & i.date.isSmallerThanValue(end)))
          .get();

  Future<List<CustomerPayment>> getPaymentsBetween(DateTime start, DateTime end) =>
      (db.select(db.customerPayments)
            ..where((p) =>
                p.date.isBiggerOrEqualValue(start) & p.date.isSmallerThanValue(end)))
          .get();

  Future<Customer?> getCustomerById(int id) =>
      (db.select(db.customers)..where((c) => c.id.equals(id))).getSingleOrNull();

  /// كل فواتير الزبون كاملة (مرتبة تصاعدياً) — لكشف الحساب
  Future<List<InvoiceWithItems>> getAllInvoicesWithItemsForCustomer(
      int customerId) async {
    final invoices = await (db.select(db.customerInvoices)
          ..where((i) => i.customerId.equals(customerId))
          ..orderBy([(i) => OrderingTerm.asc(i.date)]))
        .get();
    final result = <InvoiceWithItems>[];
    for (final inv in invoices) {
      final withItems = await getInvoiceWithItems(inv.id);
      if (withItems != null) result.add(withItems);
    }
    return result;
  }

  /// كل دفعات الزبون كاملة (مرتبة تصاعدياً) — لكشف الحساب
  Future<List<CustomerPayment>> getAllPaymentsForCustomer(int customerId) =>
      (db.select(db.customerPayments)
            ..where((p) => p.customerId.equals(customerId))
            ..orderBy([(p) => OrderingTerm.asc(p.date)]))
          .get();

  Future<List<InvoiceWithItems>> getInvoiceWithItemsListBetween(
      DateTime start, DateTime end) async {
    final invoices = await getInvoicesBetween(start, end);
    final result = <InvoiceWithItems>[];
    for (final invoice in invoices) {
      final withItems = await getInvoiceWithItems(invoice.id);
      if (withItems != null) result.add(withItems);
    }
    return result;
  }

  Future<double> getTotalReceivables() async {
    final customers = await db.select(db.customers).get();
    double total = 0;
    for (final c in customers) total += await getCustomerBalance(c.id);
    return total;
  }

  // ============================================================
  // فواتير مرتجعة: إعادة منتجات من الزبون — تُضاف الكمية للمخزون
  // ويُخصم المبلغ من رصيد الزبون المستحق
  // ============================================================
  Future<void> addReturnWithItems({
    required int customerId,
    required List<InvoiceItemDetail> items,
    String notes = '',
    DateTime? date,
  }) async {
    if (items.isEmpty) throw Exception('فاتورة المرتجع لا يمكن أن تكون فارغة');
    final total = items.fold(0.0, (sum, i) => sum + i.totalUsd);

    await db.transaction(() async {
      final returnId = await db.into(db.customerReturns).insert(
            CustomerReturnsCompanion.insert(
              customerId: customerId,
              totalAmountUsd: total,
              notes: Value(notes),
              date: date != null ? Value(date) : const Value.absent(),
            ),
          );

      for (final detail in items) {
        await db.into(db.customerReturnItems).insert(
              CustomerReturnItemsCompanion.insert(
                returnId: returnId,
                productId: Value(detail.item.productId),
                quantity: detail.item.quantity,
                unitPriceUsd: detail.item.unitPriceUsd,
                productNameSnapshot:
                    Value(detail.product?.name ?? 'منتج محذوف'),
              ),
            );
        if (detail.product != null) {
          // إعادة الكمية للمخزون (عكس البيع)
          final newQty = detail.product!.quantity + detail.item.quantity;
          await (db.update(db.products)
                ..where((p) => p.id.equals(detail.product!.id)))
              .write(ProductsCompanion(
            quantity: Value(newQty),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }
    });
  }

  Future<CustomerReturnWithItems?> getReturnWithItems(int returnId) async {
    final returnInvoice = await (db.select(db.customerReturns)
          ..where((r) => r.id.equals(returnId)))
        .getSingleOrNull();
    if (returnInvoice == null) return null;

    final items = await (db.select(db.customerReturnItems)
          ..where((i) => i.returnId.equals(returnId)))
        .get();

    final details = <ReturnItemDetail>[];
    for (final item in items) {
      Product? product;
      if (item.productId != null) {
        product = await (db.select(db.products)
              ..where((p) => p.id.equals(item.productId!)))
            .getSingleOrNull();
      }
      details.add(ReturnItemDetail(item: item, product: product));
    }
    return CustomerReturnWithItems(returnInvoice: returnInvoice, items: details);
  }

  Stream<List<CustomerReturnWithItems>> watchReturnsForCustomer(
      int customerId) async* {
    yield* db.customerReturns.select().watch().asyncMap((_) async {
      final returns = await (db.select(db.customerReturns)
            ..where((r) => r.customerId.equals(customerId))
            ..orderBy([(r) => OrderingTerm.desc(r.date)]))
          .get();

      final result = <CustomerReturnWithItems>[];
      for (final r in returns) {
        final withItems = await getReturnWithItems(r.id);
        if (withItems != null) result.add(withItems);
      }
      return result;
    });
  }

  /// كل مرتجعات الزبون كاملة (مرتبة تصاعدياً) — لكشف الحساب
  Future<List<CustomerReturnWithItems>> getAllReturnsForCustomer(
      int customerId) async {
    final returns = await (db.select(db.customerReturns)
          ..where((r) => r.customerId.equals(customerId))
          ..orderBy([(r) => OrderingTerm.asc(r.date)]))
        .get();
    final result = <CustomerReturnWithItems>[];
    for (final r in returns) {
      final withItems = await getReturnWithItems(r.id);
      if (withItems != null) result.add(withItems);
    }
    return result;
  }

  // ============================================================
  // زبون "بيع سريع" ثابت — لتسجيل مبيعات يومية لا تحتاج ربط
  // بزبون فعلي (تحدَّث المخزون والتقارير بدقة دون تتبع دين)
  // ============================================================
  static const String walkInCustomerName = 'زبون عادي (بيع سريع)';

  Future<Customer> getOrCreateWalkInCustomer() async {
    final existing = await (db.select(db.customers)
          ..where((c) => c.name.equals(walkInCustomerName)))
        .getSingleOrNull();
    if (existing != null) return existing;

    final id = await db.into(db.customers).insert(
          CustomersCompanion.insert(
            name: walkInCustomerName,
            phone: const Value('0900000000'),
            notes: const Value('حساب تلقائي لمبيعات لا تحتاج بيانات الزبون'),
          ),
        );
    return (await getCustomerById(id))!;
  }
}
