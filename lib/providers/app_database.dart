import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ===== الجداول =====

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get category => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text().withDefault(const Constant('قطعة'))();
  RealColumn get purchasePriceUsd => real()();
  RealColumn get salePriceUsd => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
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
  IntColumn get customerId => integer().references(Customers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmountUsd => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class CustomerInvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get invoiceId => integer().references(CustomerInvoices, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id, onDelete: KeyAction.restrict)();
  RealColumn get quantity => real()();
  RealColumn get unitPriceUsd => real()();
}

class CustomerPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get amountUsd => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();
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
  IntColumn get supplierId => integer().references(Suppliers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalAmountUsd => real()();
  TextColumn get productsDescription => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class SupplierPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  RealColumn get amountUsd => real()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

class ExchangeRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get rate => real()();
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();
}

// ===== قاعدة البيانات =====

@DriftDatabase(tables: [
  Products,
  Customers,
  CustomerInvoices,
  CustomerInvoiceItems,
  CustomerPayments,
  Suppliers,
  SupplierInvoices,
  SupplierPayments,
  ExchangeRates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'store_db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}