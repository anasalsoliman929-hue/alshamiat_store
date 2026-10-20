import 'package:drift/drift.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get category => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text().withDefault(const Constant('قطعة'))();
  RealColumn get purchasePriceUsd => real()();
  RealColumn get salePriceUsd => real()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, category}
      ];
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CustomerInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmountUsd => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class CustomerInvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId =>
      integer().references(CustomerInvoices, #id, onDelete: KeyAction.cascade)();
  // nullable: إذا حُذف المنتج يصبح null لكن الفاتورة تبقى
  IntColumn get productId =>
      integer().nullable().references(Products, #id, onDelete: KeyAction.setNull)();
  RealColumn get quantity => real()();
  RealColumn get unitPriceUsd => real()();
  // snapshot لاسم المنتج وقت البيع
  TextColumn get productNameSnapshot =>
      text().withDefault(const Constant('منتج محذوف'))();
}

class CustomerPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get amountUsd => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class CustomerReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmountUsd => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class CustomerReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId =>
      integer().references(CustomerReturns, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId =>
      integer().nullable().references(Products, #id, onDelete: KeyAction.setNull)();
  RealColumn get quantity => real()();
  RealColumn get unitPriceUsd => real()();
  TextColumn get productNameSnapshot =>
      text().withDefault(const Constant('منتج محذوف'))();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class SupplierInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId =>
      integer().references(Suppliers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmountUsd => real()();
  TextColumn get productsDescription => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class SupplierInvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId =>
      integer().references(SupplierInvoices, #id, onDelete: KeyAction.cascade)();
  // nullable: إذا أُرشف/حُذف المنتج يصبح null لكن الفاتورة تبقى
  IntColumn get productId =>
      integer().nullable().references(Products, #id, onDelete: KeyAction.setNull)();
  RealColumn get quantity => real()();
  RealColumn get unitPurchasePriceUsd => real()();
  // snapshot لاسم المنتج وقت الشراء
  TextColumn get productNameSnapshot =>
      text().withDefault(const Constant('منتج محذوف'))();
}

class SupplierPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId =>
      integer().references(Suppliers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get amountUsd => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class PersonalExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
  RealColumn get amountUsd => real()();
  TextColumn get category => text().withDefault(const Constant('عام'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

class ProductLosses extends Table {
  IntColumn get id => integer().autoIncrement()();
  // nullable: إذا أُرشف/حُذف المنتج يصبح null لكن سجل الخسارة يبقى
  IntColumn get productId =>
      integer().nullable().references(Products, #id, onDelete: KeyAction.setNull)();
  TextColumn get productNameSnapshot =>
      text().withDefault(const Constant('منتج محذوف'))();
  RealColumn get quantity => real()();
  // القيمة المقدَّرة للخسارة بسعر التكلفة (الشراء) وقت وقوعها
  RealColumn get estimatedValueUsd => real()();
  TextColumn get reason => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
}

class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get rate => real()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
}
