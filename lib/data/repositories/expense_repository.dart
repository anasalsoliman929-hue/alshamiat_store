import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ExpenseRepository {
  final AppDatabase db;
  ExpenseRepository(this.db);

  // ============================================================
  // المصاريف الشخصية
  // ============================================================
  Stream<List<PersonalExpense>> watchAllExpenses() =>
      (db.select(db.personalExpenses)
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .watch();

  Future<int> addExpense(PersonalExpensesCompanion e) =>
      db.into(db.personalExpenses).insert(e);

  Future<bool> updateExpense(PersonalExpense e) =>
      db.update(db.personalExpenses).replace(e);

  Future<int> deleteExpense(int id) =>
      (db.delete(db.personalExpenses)..where((e) => e.id.equals(id))).go();

  Future<List<PersonalExpense>> getExpensesBetween(
          DateTime start, DateTime end) =>
      (db.select(db.personalExpenses)
            ..where((e) =>
                e.date.isBiggerOrEqualValue(start) & e.date.isSmallerThanValue(end)))
          .get();

  Future<double> getTotalExpenses() async {
    final total = db.personalExpenses.amountUsd.sum();
    final query = db.selectOnly(db.personalExpenses)..addColumns([total]);
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  // ============================================================
  // خسائر المنتجات (تلف/انتهاء صلاحية/فقدان...)
  // ============================================================
  Stream<List<ProductLossesData>> watchAllLosses() =>
      (db.select(db.productLosses)
            ..orderBy([(l) => OrderingTerm.desc(l.date)]))
          .watch();

  Future<List<ProductLossesData>> getLossesBetween(DateTime start, DateTime end) =>
      (db.select(db.productLosses)
            ..where((l) =>
                l.date.isBiggerOrEqualValue(start) & l.date.isSmallerThanValue(end)))
          .get();

  Future<double> getTotalLossesValue() async {
    final total = db.productLosses.estimatedValueUsd.sum();
    final query = db.selectOnly(db.productLosses)..addColumns([total]);
    final row = await query.getSingle();
    return row.read(total) ?? 0;
  }

  /// تسجيل خسارة منتج: تُخصم الكمية من المخزون تلقائياً، وتُحسب
  /// القيمة المقدَّرة للخسارة بسعر تكلفة (شراء) المنتج الحالي.
  Future<void> addLoss({
    required int? productId,
    required double quantity,
    String reason = '',
    DateTime? date,
  }) async {
    await db.transaction(() async {
      String productName = 'منتج محذوف';
      double estimatedValue = 0;

      if (productId != null) {
        final product = await (db.select(db.products)
              ..where((p) => p.id.equals(productId)))
            .getSingle();
        productName = product.name;
        estimatedValue = quantity * product.purchasePriceUsd;

        final newQty = product.quantity - quantity;
        await (db.update(db.products)..where((p) => p.id.equals(productId)))
            .write(ProductsCompanion(
          quantity: Value(newQty < 0 ? 0 : newQty),
          updatedAt: Value(DateTime.now()),
        ));
      }

      await db.into(db.productLosses).insert(
            ProductLossesCompanion.insert(
              productId: Value(productId),
              productNameSnapshot: Value(productName),
              quantity: quantity,
              estimatedValueUsd: estimatedValue,
              reason: Value(reason),
              date: date != null ? Value(date) : const Value.absent(),
            ),
          );
    });
  }

  /// حذف سجل خسارة: يعيد الكمية للمخزون (تراجع عن الخصم).
  Future<void> deleteLoss(int id) async {
    await db.transaction(() async {
      final loss = await (db.select(db.productLosses)
            ..where((l) => l.id.equals(id)))
          .getSingle();

      if (loss.productId != null) {
        final product = await (db.select(db.products)
              ..where((p) => p.id.equals(loss.productId!)))
            .getSingleOrNull();
        if (product != null) {
          await (db.update(db.products)
                ..where((p) => p.id.equals(loss.productId!)))
              .write(ProductsCompanion(
            quantity: Value(product.quantity + loss.quantity),
            updatedAt: Value(DateTime.now()),
          ));
        }
      }

      await (db.delete(db.productLosses)..where((l) => l.id.equals(id))).go();
    });
  }
}
