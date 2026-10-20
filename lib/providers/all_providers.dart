import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/settings_service.dart';
import '../core/services/backup_service.dart';
import '../core/services/backup_scheduler.dart';
import '../core/services/local_backup_service.dart';
import '../data/database/app_database.dart';
import '../data/models/invoice_with_items.dart';
import '../data/repositories/product_repository.dart';
import '../data/repositories/customer_repository.dart';
import '../data/repositories/supplier_repository.dart';
import '../data/repositories/expense_repository.dart';

// ============================================================
// DATABASE
// ============================================================
final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// يصدر حدثاً عند أي تعديل على أي جدول أساسي (فاتورة، دفعة، مصروف،
/// خسارة...). تعتمد عليه شاشات التقارير/الإشعارات/الفواتير المجمّعة
/// لتُحدَّث تلقائياً بدل إعادة تشغيل التطبيق.
final _dataChangeProvider =
    StreamProvider<void>((ref) => ref.watch(databaseProvider).dataChangeStream);

// ============================================================
// LOCAL BACKUP (حفظ تلقائي في ملفات الجهاز)
// ============================================================
final localBackupServiceProvider =
    Provider<LocalBackupService>((ref) => LocalBackupService());

final backupFolderPathProvider = FutureProvider<String>((ref) {
  return ref.watch(localBackupServiceProvider).getBackupFolderPath();
});

// ============================================================
// SETTINGS
// ============================================================
final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService());

class SettingsState {
  final double manualExchangeRate;
  final bool autoBackupEnabled;
  final int autoBackupHour;
  final String themeMode; // 'system' | 'light' | 'dark'
  final bool isLoaded;

  const SettingsState({
    this.manualExchangeRate = 0,
    this.autoBackupEnabled = false,
    this.autoBackupHour = 21,
    this.themeMode = 'system',
    this.isLoaded = false,
  });

  SettingsState copyWith({
    double? manualExchangeRate,
    bool? autoBackupEnabled,
    int? autoBackupHour,
    String? themeMode,
    bool? isLoaded,
  }) =>
      SettingsState(
        manualExchangeRate: manualExchangeRate ?? this.manualExchangeRate,
        autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
        autoBackupHour: autoBackupHour ?? this.autoBackupHour,
        themeMode: themeMode ?? this.themeMode,
        isLoaded: isLoaded ?? this.isLoaded,
      );

  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsService service;
  SettingsNotifier(this.service) : super(const SettingsState()) { _load(); }

  Future<void> _load() async {
    state = state.copyWith(
      manualExchangeRate: await service.getManualExchangeRate() ?? 0,
      autoBackupEnabled: await service.getAutoBackupEnabled(),
      autoBackupHour: await service.getAutoBackupHour(),
      themeMode: await service.getThemeMode(),
      isLoaded: true,
    );
  }

  Future<void> setManualExchangeRate(double v) async {
    await service.setManualExchangeRate(v);
    state = state.copyWith(manualExchangeRate: v);
  }

  Future<void> setAutoBackupEnabled(bool v) async {
    await service.setAutoBackupEnabled(v);
    state = state.copyWith(autoBackupEnabled: v);
    if (v) {
      await BackupScheduler.scheduleDailyLocalSnapshot(state.autoBackupHour);
    } else {
      await BackupScheduler.cancelDailyLocalSnapshot();
    }
  }

  Future<void> setAutoBackupHour(int v) async {
    await service.setAutoBackupHour(v);
    state = state.copyWith(autoBackupHour: v);
    if (state.autoBackupEnabled) {
      await BackupScheduler.scheduleDailyLocalSnapshot(v);
    }
  }

  Future<void> setThemeMode(String v) async {
    await service.setThemeMode(v);
    state = state.copyWith(themeMode: v);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
        (ref) => SettingsNotifier(ref.watch(settingsServiceProvider)));

// ============================================================
// سعر الصرف (يدوي فقط)
// ============================================================
// يُدخله المستخدم يدوياً من الإعدادات فقط، لا يوجد أي جلب تلقائي
// من الإنترنت. أُبقي عليه كـ FutureProvider (يُحل فوراً) حتى تبقى
// كل واجهات .when(...) في التطبيق تعمل دون تعديل.
final currentExchangeRateProvider = FutureProvider<double>((ref) async {
  final settings = ref.watch(settingsProvider);
  return settings.manualExchangeRate;
});

// ============================================================
// PRODUCTS
// ============================================================
final productRepositoryProvider = Provider<ProductRepository>(
    (ref) => ProductRepository(ref.watch(databaseProvider)));

final productsStreamProvider = StreamProvider<List<Product>>(
    (ref) => ref.watch(productRepositoryProvider).watchActiveProducts());

final archivedProductsProvider = StreamProvider<List<Product>>(
    (ref) => ref.watch(productRepositoryProvider).watchArchivedProducts());

final productSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  final query = ref.watch(productSearchQueryProvider);
  return productsAsync.whenData((products) {
    if (query.isEmpty) return products;
    return products
        .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  });
});

class ProductActions {
  final ProductRepository repo;
  ProductActions(this.repo);

  Future<bool> addProduct({
    required String name,
    required String category,
    required double quantity,
    required String unit,
    required double purchasePriceUsd,
    required double salePriceUsd,
  }) async {
    final result = await repo.addProduct(ProductsCompanion.insert(
      name: name,
      category: category,
      quantity: quantity,
      unit: Value(unit),
      purchasePriceUsd: purchasePriceUsd,
      salePriceUsd: salePriceUsd,
    ));
    return result != null;
  }

  Future<bool> updateProduct(Product product) => repo.updateProduct(product);

  Future<String> tryArchiveProduct(int id) async {
    final canArchive = await repo.canArchiveProduct(id);
    if (canArchive) {
      await repo.archiveProduct(id);
      return 'archived';
    }
    return 'has_invoices';
  }

  Future<void> unarchiveProduct(int id) => repo.unarchiveProduct(id);
}

final productActionsProvider = Provider<ProductActions>(
    (ref) => ProductActions(ref.watch(productRepositoryProvider)));

// ============================================================
// CUSTOMERS
// ============================================================
final customerRepositoryProvider = Provider<CustomerRepository>(
    (ref) => CustomerRepository(ref.watch(databaseProvider)));

final customersStreamProvider = StreamProvider<List<Customer>>(
    (ref) => ref.watch(customerRepositoryProvider).watchAllCustomers());

final customerInvoicesWithItemsProvider =
    StreamProvider.family<List<InvoiceWithItems>, int>((ref, customerId) => ref
        .watch(customerRepositoryProvider)
        .watchInvoicesWithItemsForCustomer(customerId));

final customerPaymentsProvider =
    StreamProvider.family<List<CustomerPayment>, int>((ref, customerId) => ref
        .watch(customerRepositoryProvider)
        .watchPaymentsForCustomer(customerId));

final customerReturnsProvider =
    StreamProvider.family<List<CustomerReturnWithItems>, int>(
        (ref, customerId) => ref
            .watch(customerRepositoryProvider)
            .watchReturnsForCustomer(customerId));

final customerBalanceProvider =
    FutureProvider.family<double, int>((ref, customerId) async {
  ref.watch(customerInvoicesWithItemsProvider(customerId));
  ref.watch(customerPaymentsProvider(customerId));
  ref.watch(customerReturnsProvider(customerId));
  return ref.watch(customerRepositoryProvider).getCustomerBalance(customerId);
});

/// زبون "بيع سريع" ثابت يُنشأ تلقائياً عند أول استخدام
final walkInCustomerProvider = FutureProvider<Customer>(
    (ref) => ref.watch(customerRepositoryProvider).getOrCreateWalkInCustomer());

class CustomerActions {
  final CustomerRepository repo;
  CustomerActions(this.repo);

  Future<void> addCustomer(
          {required String name, String phone = '', String notes = ''}) =>
      repo.addCustomer(CustomersCompanion.insert(
          name: name, phone: Value(phone), notes: Value(notes)));

  Future<void> updateCustomer(Customer c) => repo.updateCustomer(c);
  Future<void> deleteCustomer(int id) => repo.deleteCustomer(id);

  Future<void> addInvoiceWithItems({
    required int customerId,
    required List<InvoiceItemDetail> items,
    String notes = '',
    DateTime? date,
  }) =>
      repo.addInvoiceWithItems(
          customerId: customerId, items: items, notes: notes, date: date);

  Future<void> updateInvoiceWithItems({
    required int invoiceId,
    required int customerId,
    required List<InvoiceItemDetail> newItems,
    String notes = '',
    DateTime? date,
  }) =>
      repo.updateInvoiceWithItems(
        invoiceId: invoiceId,
        customerId: customerId,
        newItems: newItems,
        notes: notes,
        date: date,
      );

  Future<void> addPayment({
    required int customerId,
    required double amountUsd,
    String notes = '',
    DateTime? date,
  }) =>
      repo.addPayment(CustomerPaymentsCompanion.insert(
        customerId: customerId,
        amountUsd: amountUsd,
        notes: Value(notes),
        date: date != null ? Value(date) : const Value.absent(),
      ));

  Future<bool> updatePayment(CustomerPayment payment) =>
      repo.updatePayment(payment);

  /// فاتورة مرتجعة: تعيد الكمية للمخزون وتخصم المبلغ من رصيد الزبون
  Future<void> addReturnWithItems({
    required int customerId,
    required List<InvoiceItemDetail> items,
    String notes = '',
    DateTime? date,
  }) =>
      repo.addReturnWithItems(
          customerId: customerId, items: items, notes: notes, date: date);
}

final customerActionsProvider = Provider<CustomerActions>(
    (ref) => CustomerActions(ref.watch(customerRepositoryProvider)));

// ============================================================
// SUPPLIERS
// ============================================================
final supplierRepositoryProvider = Provider<SupplierRepository>(
    (ref) => SupplierRepository(ref.watch(databaseProvider)));

final suppliersStreamProvider = StreamProvider<List<Supplier>>(
    (ref) => ref.watch(supplierRepositoryProvider).watchAllSuppliers());

final supplierInvoicesWithItemsProvider =
    StreamProvider.family<List<SupplierInvoiceWithItems>, int>(
        (ref, supplierId) => ref
            .watch(supplierRepositoryProvider)
            .watchInvoicesWithItemsForSupplier(supplierId));

final supplierPaymentsProvider =
    StreamProvider.family<List<SupplierPayment>, int>((ref, supplierId) => ref
        .watch(supplierRepositoryProvider)
        .watchPaymentsForSupplier(supplierId));

final supplierBalanceProvider =
    FutureProvider.family<double, int>((ref, supplierId) async {
  ref.watch(supplierInvoicesWithItemsProvider(supplierId));
  ref.watch(supplierPaymentsProvider(supplierId));
  return ref.watch(supplierRepositoryProvider).getSupplierBalance(supplierId);
});

class SupplierActions {
  final SupplierRepository repo;
  SupplierActions(this.repo);

  Future<void> addSupplier(
          {required String name, String phone = '', String notes = ''}) =>
      repo.addSupplier(SuppliersCompanion.insert(
          name: name, phone: Value(phone), notes: Value(notes)));

  Future<void> updateSupplier(Supplier s) => repo.updateSupplier(s);
  Future<void> deleteSupplier(int id) => repo.deleteSupplier(id);

  /// إضافة فاتورة شراء بعناصر مرتبطة بالمنتجات: منتج موجود -> تُضاف
  /// الكمية له، منتج جديد -> يُنشأ بمعلوماته وكميته وسعره.
  Future<void> addPurchaseInvoiceWithItems({
    required int supplierId,
    required List<PurchaseLineInput> lines,
    String notes = '',
    DateTime? date,
  }) =>
      repo.addPurchaseInvoiceWithItems(
        supplierId: supplierId,
        lines: lines,
        notes: notes,
        date: date,
      );

  Future<void> updatePurchaseInvoiceWithItems({
    required int invoiceId,
    required int supplierId,
    required List<PurchaseLineInput> newLines,
    String notes = '',
    DateTime? date,
  }) =>
      repo.updatePurchaseInvoiceWithItems(
        invoiceId: invoiceId,
        supplierId: supplierId,
        newLines: newLines,
        notes: notes,
        date: date,
      );

  Future<void> addPayment({
    required int supplierId,
    required double amountUsd,
    String notes = '',
    DateTime? date,
  }) =>
      repo.addPayment(SupplierPaymentsCompanion.insert(
        supplierId: supplierId,
        amountUsd: amountUsd,
        notes: Value(notes),
        date: date != null ? Value(date) : const Value.absent(),
      ));

  Future<bool> updatePayment(SupplierPayment p) => repo.updatePayment(p);
  Future<void> deletePayment(int id) => repo.deletePayment(id);
}

final supplierActionsProvider = Provider<SupplierActions>(
    (ref) => SupplierActions(ref.watch(supplierRepositoryProvider)));

// ============================================================
// المصاريف الشخصية وخسائر المنتجات
// ============================================================
final expenseRepositoryProvider = Provider<ExpenseRepository>(
    (ref) => ExpenseRepository(ref.watch(databaseProvider)));

final personalExpensesStreamProvider = StreamProvider<List<PersonalExpense>>(
    (ref) => ref.watch(expenseRepositoryProvider).watchAllExpenses());

final productLossesStreamProvider = StreamProvider<List<ProductLossesData>>(
    (ref) => ref.watch(expenseRepositoryProvider).watchAllLosses());

class ExpenseActions {
  final ExpenseRepository repo;
  ExpenseActions(this.repo);

  Future<void> addExpense({
    required String description,
    required double amountUsd,
    String category = 'عام',
    String notes = '',
    DateTime? date,
  }) =>
      repo.addExpense(PersonalExpensesCompanion.insert(
        description: description,
        amountUsd: amountUsd,
        category: Value(category),
        notes: Value(notes),
        date: date != null ? Value(date) : const Value.absent(),
      ));

  Future<void> deleteExpense(int id) => repo.deleteExpense(id);

  /// تسجيل خسارة منتج (تلف/انتهاء صلاحية/فقدان...) — تُخصم الكمية
  /// تلقائياً من المخزون وتُحسب القيمة بسعر التكلفة الحالي للمنتج.
  Future<void> addLoss({
    required int? productId,
    required double quantity,
    String reason = '',
    DateTime? date,
  }) =>
      repo.addLoss(
          productId: productId, quantity: quantity, reason: reason, date: date);

  Future<void> deleteLoss(int id) => repo.deleteLoss(id);
}

final expenseActionsProvider = Provider<ExpenseActions>(
    (ref) => ExpenseActions(ref.watch(expenseRepositoryProvider)));

// ============================================================
// REPORTS
// ============================================================
class DailyReportData {
  final double todayCustomerInvoicesTotal;
  final double todayCustomerPaymentsTotal;
  final double todaySupplierInvoicesTotal;
  final double todaySupplierPaymentsTotal;
  final double todayExpensesTotal;
  final double todayLossesValue;
  final double totalReceivables;
  final double totalPayables;
  final double inventorySaleValue;
  final double inventoryPurchaseValue;
  final double potentialProfit;
  final List<Product> lowStockProducts;

  const DailyReportData({
    required this.todayCustomerInvoicesTotal,
    required this.todayCustomerPaymentsTotal,
    required this.todaySupplierInvoicesTotal,
    required this.todaySupplierPaymentsTotal,
    required this.todayExpensesTotal,
    required this.todayLossesValue,
    required this.totalReceivables,
    required this.totalPayables,
    required this.inventorySaleValue,
    required this.inventoryPurchaseValue,
    required this.potentialProfit,
    required this.lowStockProducts,
  });
}

final dailyReportProvider = FutureProvider<DailyReportData>((ref) async {
  // يعيد الحساب تلقائياً عند أي تعديل على البيانات (بلا إعادة تشغيل)
  ref.watch(_dataChangeProvider);

  final productRepo = ref.watch(productRepositoryProvider);
  final customerRepo = ref.watch(customerRepositoryProvider);
  final supplierRepo = ref.watch(supplierRepositoryProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);

  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  double sum(List items, double Function(dynamic) getter) =>
      items.fold(0, (s, i) => s + getter(i));

  final customerInvoices = await customerRepo.getInvoicesBetween(startOfDay, endOfDay);
  final customerPayments = await customerRepo.getPaymentsBetween(startOfDay, endOfDay);
  final supplierInvoices = await supplierRepo.getInvoicesBetween(startOfDay, endOfDay);
  final supplierPayments = await supplierRepo.getPaymentsBetween(startOfDay, endOfDay);
  final todayExpenses = await expenseRepo.getExpensesBetween(startOfDay, endOfDay);
  final todayLosses = await expenseRepo.getLossesBetween(startOfDay, endOfDay);
  final inventoryValue = await productRepo.getInventoryValue();
  final lowStock = await productRepo.getLowStockActiveProducts();

  return DailyReportData(
    todayCustomerInvoicesTotal: sum(customerInvoices, (i) => i.totalAmountUsd),
    todayCustomerPaymentsTotal: sum(customerPayments, (p) => p.amountUsd),
    todaySupplierInvoicesTotal: sum(supplierInvoices, (i) => i.totalAmountUsd),
    todaySupplierPaymentsTotal: sum(supplierPayments, (p) => p.amountUsd),
    todayExpensesTotal: sum(todayExpenses, (e) => e.amountUsd),
    todayLossesValue: sum(todayLosses, (l) => l.estimatedValueUsd),
    totalReceivables: await customerRepo.getTotalReceivables(),
    totalPayables: await supplierRepo.getTotalPayables(),
    inventorySaleValue: inventoryValue['saleValue']!,
    inventoryPurchaseValue: inventoryValue['purchaseValue']!,
    potentialProfit: inventoryValue['potentialProfit']!,
    lowStockProducts: lowStock,
  );
});

/// نطاق فواتير (يوم/أسبوع): تجميع فواتير البيع والشراء معاً لعرضها
/// في صفحة الفواتير الكاملة.
class InvoicesRange {
  final DateTime start;
  final DateTime end;
  const InvoicesRange({required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      other is InvoicesRange && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
}

class InvoicesRangeData {
  final List<InvoiceWithItems> sales;
  final List<SupplierInvoiceWithItems> purchases;
  const InvoicesRangeData({required this.sales, required this.purchases});

  double get salesTotal => sales.fold(0, (s, i) => s + i.totalUsd);
  double get purchasesTotal => purchases.fold(0, (s, i) => s + i.totalUsd);
}

final invoicesForRangeProvider =
    FutureProvider.family<InvoicesRangeData, InvoicesRange>((ref, range) async {
  ref.watch(_dataChangeProvider);
  final customerRepo = ref.watch(customerRepositoryProvider);
  final supplierRepo = ref.watch(supplierRepositoryProvider);
  final sales =
      await customerRepo.getInvoiceWithItemsListBetween(range.start, range.end);
  final purchases =
      await supplierRepo.getInvoiceWithItemsListBetween(range.start, range.end);
  return InvoicesRangeData(sales: sales, purchases: purchases);
});

/// صفحة الإشعارات: تنبيهات نفاذ/انخفاض المخزون، ومستحقات الزبائن
/// والموردين المتراكمة.
class CustomerAlert {
  final Customer customer;
  final double balance;
  const CustomerAlert({required this.customer, required this.balance});
}

class SupplierAlert {
  final Supplier supplier;
  final double balance;
  const SupplierAlert({required this.supplier, required this.balance});
}

class NotificationsData {
  final List<Product> outOfStockProducts;
  final List<Product> lowStockProducts;
  final List<CustomerAlert> customersWithDebt;
  final List<SupplierAlert> suppliersOwed;

  const NotificationsData({
    required this.outOfStockProducts,
    required this.lowStockProducts,
    required this.customersWithDebt,
    required this.suppliersOwed,
  });

  int get totalCount =>
      outOfStockProducts.length +
      lowStockProducts.length +
      customersWithDebt.length +
      suppliersOwed.length;
}

final notificationsProvider = FutureProvider<NotificationsData>((ref) async {
  ref.watch(_dataChangeProvider);
  final productRepo = ref.watch(productRepositoryProvider);
  final customerRepo = ref.watch(customerRepositoryProvider);
  final supplierRepo = ref.watch(supplierRepositoryProvider);

  final lowStock = await productRepo.getLowStockActiveProducts();
  final outOfStock = lowStock.where((p) => p.quantity <= 0).toList();
  final lowButInStock =
      lowStock.where((p) => p.quantity > 0).toList();

  final customers = await customerRepo.watchAllCustomers().first;
  final customerAlerts = <CustomerAlert>[];
  for (final c in customers) {
    final balance = await customerRepo.getCustomerBalance(c.id);
    if (balance > 0) customerAlerts.add(CustomerAlert(customer: c, balance: balance));
  }
  customerAlerts.sort((a, b) => b.balance.compareTo(a.balance));

  final suppliers = await supplierRepo.watchAllSuppliers().first;
  final supplierAlerts = <SupplierAlert>[];
  for (final s in suppliers) {
    final balance = await supplierRepo.getSupplierBalance(s.id);
    if (balance > 0) supplierAlerts.add(SupplierAlert(supplier: s, balance: balance));
  }
  supplierAlerts.sort((a, b) => b.balance.compareTo(a.balance));

  return NotificationsData(
    outOfStockProducts: outOfStock,
    lowStockProducts: lowButInStock,
    customersWithDebt: customerAlerts,
    suppliersOwed: supplierAlerts,
  );
});

// ============================================================
// BACKUP (محلي فقط - بلا تلغرام)
// ============================================================
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

enum BackupStatus { idle, loading, success, error }

class BackupState {
  final BackupStatus status;
  final String? errorMessage;
  final String? successMessage;
  const BackupState(
      {this.status = BackupStatus.idle,
      this.errorMessage,
      this.successMessage});
}

class BackupNotifier extends StateNotifier<BackupState> {
  final BackupService backupService;
  final Ref ref;
  BackupNotifier(this.backupService, this.ref) : super(const BackupState());

  Future<void> restoreBackup() async {
    state = const BackupState(status: BackupStatus.loading);
    try {
      final file = await backupService.pickBackupFile();
      if (file == null) { state = const BackupState(status: BackupStatus.idle); return; }
      final db = ref.read(databaseProvider);
      await backupService.restoreDatabase(db: db, backupFile: file);
      // يعيد فتح قاعدة البيانات المستعادة فوراً ضمن الجلسة الحالية
      // (بدل اشتراط إعادة تشغيل التطبيق) — كل الشاشات تتحدّث تلقائياً
      // لأنها تعتمد على databaseProvider عبر ref.watch.
      ref.invalidate(databaseProvider);
      state = const BackupState(
          status: BackupStatus.success,
          successMessage: '✅ تم استرجاع النسخة الاحتياطية بنجاح.');
    } catch (e) {
      state = BackupState(status: BackupStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> saveTimestampedLocalBackup() async {
    state = const BackupState(status: BackupStatus.loading);
    try {
      final service = ref.read(localBackupServiceProvider);
      final file = await service.saveTimestampedSnapshot();
      state = BackupState(
        status: BackupStatus.success,
        successMessage: '✅ تم حفظ نسخة في: ${file.path}',
      );
    } catch (e) {
      state = BackupState(status: BackupStatus.error, errorMessage: e.toString());
    }
  }

  void reset() => state = const BackupState();
}

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>(
    (ref) => BackupNotifier(ref.watch(backupServiceProvider), ref));

// ============================================================
// CLEAR DATABASE
// ============================================================
final clearDatabaseProvider = Provider((ref) {
  return () async {
    final db = ref.read(databaseProvider);
    await db.clearAllData();
  };
});
