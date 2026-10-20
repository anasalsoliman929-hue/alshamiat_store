import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ProductRepository {
  final AppDatabase db;
  ProductRepository(this.db);

  Future<int?> addProduct(ProductsCompanion product) async {
    try {
      return await db.into(db.products).insert(product);
    } catch (e) {
      if (e.toString().contains('UNIQUE')) return null;
      rethrow;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      return await db.update(db.products).replace(product);
    } catch (e) {
      if (e.toString().contains('UNIQUE')) return false;
      rethrow;
    }
  }

  // التحقق إن كان المنتج مرتبطاً بفواتير
  Future<bool> canArchiveProduct(int id) async {
    final items = await (db.select(db.customerInvoiceItems)
          ..where((i) => i.productId.equals(id)))
        .get();
    return items.isEmpty;
  }

  /// يبحث عن منتج مؤرشف بنفس الاسم والفئة — يُستخدم لتوضيح سبب فشل
  /// الإضافة (بدل رسالة عامة) والسماح باستعادته مباشرة بدل تكراره.
  Future<Product?> findArchivedDuplicate(String name, String category) =>
      (db.select(db.products)
            ..where((p) =>
                p.name.equals(name) &
                p.category.equals(category) &
                p.isArchived.equals(true)))
          .getSingleOrNull();

  Future<void> archiveProduct(int id) async {
    await (db.update(db.products)..where((p) => p.id.equals(id)))
        .write(ProductsCompanion(
      isArchived: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> unarchiveProduct(int id) async {
    await (db.update(db.products)..where((p) => p.id.equals(id)))
        .write(ProductsCompanion(
      isArchived: const Value(false),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Stream<List<Product>> watchActiveProducts() =>
      (db.select(db.products)..where((p) => p.isArchived.equals(false))).watch();

  Stream<List<Product>> watchArchivedProducts() =>
      (db.select(db.products)..where((p) => p.isArchived.equals(true))).watch();

  Future<List<Product>> getAllProducts() => db.select(db.products).get();

  Future<List<Product>> getLowStockActiveProducts({double threshold = 5}) =>
      (db.select(db.products)
            ..where((p) =>
                p.quantity.isSmallerOrEqualValue(threshold) &
                p.isArchived.equals(false)))
          .get();

  Future<Map<String, double>> getInventoryValue() async {
    final products = await (db.select(db.products)
          ..where((p) => p.isArchived.equals(false)))
        .get();
    double saleValue = 0, purchaseValue = 0;
    for (final p in products) {
      saleValue += p.quantity * p.salePriceUsd;
      purchaseValue += p.quantity * p.purchasePriceUsd;
    }
    return {
      'saleValue': saleValue,
      'purchaseValue': purchaseValue,
      'potentialProfit': saleValue - purchaseValue,
    };
  }

  Future<void> updateQuantity(int id, double newQuantity) =>
      (db.update(db.products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(
          quantity: Value(newQuantity),
          updatedAt: Value(DateTime.now()),
        ),
      );
}
