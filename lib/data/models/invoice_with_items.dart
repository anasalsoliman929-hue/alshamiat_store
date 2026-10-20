import '../database/app_database.dart';

class InvoiceItemDetail {
  final CustomerInvoiceItem item;
  final Product? product; // nullable: المنتج قد يكون محذوفاً

  InvoiceItemDetail({required this.item, this.product});

  String get productName => product?.name ?? item.productNameSnapshot;
  double get totalUsd => item.quantity * item.unitPriceUsd;
}

class InvoiceWithItems {
  final CustomerInvoice invoice;
  final List<InvoiceItemDetail> items;

  InvoiceWithItems({required this.invoice, required this.items});

  double get totalUsd => items.fold(0, (sum, item) => sum + item.totalUsd);
}

// ============================================================
// فواتير الشراء (الموردين) — عناصر مرتبطة بالمنتجات
// ============================================================
class SupplierInvoiceItemDetail {
  final SupplierInvoiceItem item;
  final Product? product; // nullable: المنتج قد يكون محذوفاً

  SupplierInvoiceItemDetail({required this.item, this.product});

  String get productName => product?.name ?? item.productNameSnapshot;
  double get totalUsd => item.quantity * item.unitPurchasePriceUsd;
}

class SupplierInvoiceWithItems {
  final SupplierInvoice invoice;
  final List<SupplierInvoiceItemDetail> items;

  SupplierInvoiceWithItems({required this.invoice, required this.items});

  double get totalUsd => items.fold(0, (sum, item) => sum + item.totalUsd);
}

/// بيانات منتج جديد يُنشأ تلقائياً أثناء إدخال فاتورة شراء
class NewProductDraft {
  final String name;
  final String category;
  final String unit;
  final double salePriceUsd;

  const NewProductDraft({
    required this.name,
    required this.category,
    required this.unit,
    required this.salePriceUsd,
  });
}

/// سطر واحد في فاتورة شراء: إما منتج موجود (productId) أو منتج جديد (draft)
class PurchaseLineInput {
  final int? productId;
  final NewProductDraft? draft;
  final double quantity;
  final double unitPurchasePriceUsd;

  const PurchaseLineInput({
    this.productId,
    this.draft,
    required this.quantity,
    required this.unitPurchasePriceUsd,
  }) : assert(productId != null || draft != null,
            'يجب تحديد منتج موجود أو بيانات منتج جديد');

  bool get isNewProduct => productId == null;
}

// ============================================================
// فواتير مرتجعة الزبائن (إعادة منتجات وإرجاعها للمخزون)
// ============================================================
class ReturnItemDetail {
  final CustomerReturnItem item;
  final Product? product; // nullable: المنتج قد يكون محذوفاً

  ReturnItemDetail({required this.item, this.product});

  String get productName => product?.name ?? item.productNameSnapshot;
  double get totalUsd => item.quantity * item.unitPriceUsd;
}

class CustomerReturnWithItems {
  final CustomerReturn returnInvoice;
  final List<ReturnItemDetail> items;

  CustomerReturnWithItems({required this.returnInvoice, required this.items});

  double get totalUsd => items.fold(0, (sum, item) => sum + item.totalUsd);
}
