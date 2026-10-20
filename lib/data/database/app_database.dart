import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables/all_tables.dart';
import '../../core/services/local_backup_service.dart';
import '../../core/services/backup_scheduler.dart';

export 'tables/all_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Products,
  Customers,
  CustomerInvoices,
  CustomerInvoiceItems,
  CustomerPayments,
  CustomerReturns,
  CustomerReturnItems,
  Suppliers,
  SupplierInvoices,
  SupplierInvoiceItems,
  SupplierPayments,
  PersonalExpenses,
  ProductLosses,
  ExchangeRates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection()) {
    _listenForChanges();
  }

  final LocalBackupService _localBackupService = LocalBackupService();

  /// يستمع لأي تغيير في أي جدول من جداول البيانات الأساسية.
  /// يحفظ نسخة محلية فوراً ضمن نفس العملية (الحالة الطبيعية:
  /// التطبيق مفتوح أو في الخلفية)، ويجدول بالتوازي مهمة WorkManager
  /// مستقلة كشبكة أمان تعمل حتى لو أُغلق التطبيق بالكامل (force-close)
  /// مباشرة بعد التعديل قبل اكتمال الحفظ داخل العملية.
  void _listenForChanges() {
  tableUpdates(TableUpdateQuery.onAllTables({
    products,
    customers,
    customerInvoices,
    customerInvoiceItems,
    customerPayments,
    customerReturns,
    customerReturnItems,
    suppliers,
    supplierInvoices,
    supplierInvoiceItems,
    supplierPayments,
    personalExpenses,
    productLosses,
  })).listen((_) {
    // الحفظ الأساسي: فوري داخل العملية الحالية
    _localBackupService.saveLatestSnapshot();
    // شبكة الأمان: مهمة خلفية مستقلة عبر نظام التشغيل
    BackupScheduler.scheduleImmediateLocalSnapshot();
  });
}

  /// بث عام يصدر حدثاً عند أي تعديل على أي جدول أساسي. تعتمد عليه
  /// الشاشات المجمِّعة (التقارير، الإشعارات، الفواتير حسب الفترة)
  /// كي تُحدَّث تلقائياً فور إضافة/تعديل/حذف أي فاتورة أو دفعة أو
  /// مصروف أو خسارة، دون الحاجة لإعادة تشغيل التطبيق.
  Stream<void> get dataChangeStream => tableUpdates(TableUpdateQuery.onAllTables({
        products,
        customers,
        customerInvoices,
        customerInvoiceItems,
        customerPayments,
        customerReturns,
        customerReturnItems,
        suppliers,
        supplierInvoices,
        supplierInvoiceItems,
        supplierPayments,
        personalExpenses,
        productLosses,
      })).map((_) {});

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(products, products.isArchived);
          }
          if (from < 3) {
            // محاولة إضافة العمود؛ إن كان موجوداً مسبقاً سيُتجاهل الخطأ
            try {
              await migrator.addColumn(
                customerInvoiceItems,
                customerInvoiceItems.productNameSnapshot,
              );
            } catch (_) {
              // العمود موجود مسبقاً، لا حاجة لفعل شيء
            }
          }
          if (from < 4) {
            // جدول جديد: عناصر فاتورة الشراء (ربط منتجات فواتير الموردين)
            try {
              await migrator.createTable(supplierInvoiceItems);
            } catch (_) {
              // الجدول موجود مسبقاً، لا حاجة لفعل شيء
            }
          }
          if (from < 5) {
            // جداول جديدة: المصاريف الشخصية وخسائر المنتجات
            try {
              await migrator.createTable(personalExpenses);
            } catch (_) {}
            try {
              await migrator.createTable(productLosses);
            } catch (_) {}
          }
          if (from < 6) {
            // جداول جديدة: فواتير مرتجعة الزبائن
            try {
              await migrator.createTable(customerReturns);
            } catch (_) {}
            try {
              await migrator.createTable(customerReturnItems);
            } catch (_) {}
          }
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'store_db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // تفريغ كل البيانات مع الإبقاء على بنية القاعدة
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(customerInvoiceItems).go();
      await delete(customerInvoices).go();
      await delete(customerPayments).go();
      await delete(customerReturnItems).go();
      await delete(customerReturns).go();
      await delete(customers).go();
      await delete(supplierInvoiceItems).go();
      await delete(supplierInvoices).go();
      await delete(supplierPayments).go();
      await delete(suppliers).go();
      await delete(personalExpenses).go();
      await delete(productLosses).go();
      await delete(products).go();
      await delete(exchangeRates).go();
    });
  }
}