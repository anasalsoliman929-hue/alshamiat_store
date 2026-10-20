import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/database/app_database.dart';
import '../../data/models/invoice_with_items.dart';

/// اسم المتجر الظاهر في ترويسة الفاتورة
const String kStoreName = 'متجر الشاميات';

/// يبني وينسّق فواتير PDF (بيع وشراء) بشكل موحّد، ويوفر خيارات
/// المعاينة/الطباعة/المشاركة عبر حزمة printing.
///
/// الخط عربي (Amiri) مُرفق داخل التطبيق (assets/fonts) بدل تحميله من
/// الإنترنت في كل مرة — هذا يجعل توليد الفاتورة فورياً تقريباً ولا
/// يعتمد على سرعة/استقرار الشبكة.
class PdfInvoiceService {
  // الخط مشترك بين كل الاستدعاءات (static) فيُحمَّل مرة واحدة فقط
  // طوال عمر التطبيق، بدل إعادة تحميله مع كل فاتورة.
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static Future<void>? _fontLoadFuture;

  static Future<void> _ensureFonts() {
    return _fontLoadFuture ??= () async {
      final regularData =
          await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
      _regularFont = pw.Font.ttf(regularData);
      _boldFont = pw.Font.ttf(boldData);
    }();
  }

  /// فاتورة بيع (زبون)
  Future<Uint8List> buildSaleInvoicePdf({
    required InvoiceWithItems invoice,
    required String customerName,
    required String customerPhone,
    required double exchangeRate,
  }) async {
    await _ensureFonts();
    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: _regularFont, bold: _boldFont);

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => _invoiceBody(
          title: 'فاتورة مبيعات',
          invoiceId: invoice.invoice.id,
          date: invoice.invoice.date,
          partyLabel: 'الزبون',
          partyName: customerName,
          partyPhone: customerPhone,
          rows: invoice.items
              .map((d) => _Row(
                    name: d.productName,
                    quantity: d.item.quantity,
                    unitPrice: d.item.unitPriceUsd,
                    total: d.totalUsd,
                  ))
              .toList(),
          total: invoice.totalUsd,
          notes: invoice.invoice.notes,
          exchangeRate: exchangeRate,
        ),
      ),
    );
    return doc.save();
  }

  /// فاتورة شراء (مورد)
  Future<Uint8List> buildPurchaseInvoicePdf({
    required SupplierInvoiceWithItems invoice,
    required String supplierName,
    required String supplierPhone,
    required double exchangeRate,
  }) async {
    await _ensureFonts();
    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: _regularFont, bold: _boldFont);

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (context) => _invoiceBody(
          title: 'فاتورة شراء',
          invoiceId: invoice.invoice.id,
          date: invoice.invoice.date,
          partyLabel: 'المورد',
          partyName: supplierName,
          partyPhone: supplierPhone,
          rows: invoice.items
              .map((d) => _Row(
                    name: d.productName,
                    quantity: d.item.quantity,
                    unitPrice: d.item.unitPurchasePriceUsd,
                    total: d.totalUsd,
                  ))
              .toList(),
          total: invoice.totalUsd,
          notes: invoice.invoice.notes,
          exchangeRate: exchangeRate,
        ),
      ),
    );
    return doc.save();
  }

  pw.Widget _invoiceBody({
    required String title,
    required int invoiceId,
    required DateTime date,
    required String partyLabel,
    required String partyName,
    required String partyPhone,
    required List<_Row> rows,
    required double total,
    required String notes,
    required double exchangeRate,
  }) {
    final dateFormat = DateFormat('yyyy/MM/dd - HH:mm');
    final usdFormat = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
    final sypFormat = NumberFormat.currency(symbol: 'ل.س', decimalDigits: 0);

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ===== ترويسة =====
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(kStoreName,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(title,
                      style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.teal700,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('رقم الفاتورة: $invoiceId'),
                  pw.Text('التاريخ: ${dateFormat.format(date)}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.teal200, thickness: 1.2),
          pw.SizedBox(height: 12),

          // ===== بيانات الطرف الآخر =====
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('$partyLabel: $partyName',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (partyPhone.isNotEmpty) pw.Text('الهاتف: $partyPhone'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ===== جدول الأصناف =====
          // الأعمدة بترتيب RTL: من اليمين لليسار (الصنف أولاً)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.teal700),
                children: [
                  _cell('الصنف', bold: true, color: PdfColors.white),
                  _cell('الكمية', bold: true, color: PdfColors.white),
                  _cell('السعر', bold: true, color: PdfColors.white),
                  _cell('الإجمالي', bold: true, color: PdfColors.white),
                ],
              ),
              for (final r in rows)
                pw.TableRow(children: [
                  _cell(r.name),
                  _cell(_fmtQty(r.quantity)),
                  _cell(usdFormat.format(r.unitPrice)),
                  _cell(usdFormat.format(r.total)),
                ]),
            ],
          ),
          pw.SizedBox(height: 16),

          // ===== الإجمالي =====
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الإجمالي (\$):'),
                      pw.Text(usdFormat.format(total),
                          style:
                              pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (exchangeRate > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الإجمالي (ل.س):'),
                        pw.Text(sypFormat.format(total * exchangeRate),
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('ملاحظات: $notes',
                style: const pw.TextStyle(color: PdfColors.grey700)),
          ],

          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.Center(
            child: pw.Text(
              'شكراً لتعاملكم مع $kStoreName',
              style:
                  const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _cell(String text, {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Text(
          text,
          textDirection: pw.TextDirection.rtl,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.black,
            fontSize: 11,
          ),
        ),
      );

  String _fmtQty(double q) =>
      q % 1 == 0 ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  /// يفتح معاينة/طباعة/مشاركة الفاتورة (يشمل خيار "حفظ كـ PDF")
  Future<void> previewAndPrint(Uint8List bytes, String fileName) =>
      Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: fileName,
      );

  // ============================================================
  // كشف حساب كامل (زبون أو مورد): كل الفواتير (بتفاصيل المنتجات)
  // والدفعات والمرتجعات مرتبة زمنياً مع رصيد متراكم
  // ============================================================
  Future<Uint8List> buildCustomerStatementPdf({
    required String customerName,
    required String customerPhone,
    required List<InvoiceWithItems> invoices,
    required List<CustomerPayment> payments,
    List<CustomerReturnWithItems> returns = const [],
    required double exchangeRate,
  }) async {
    final entries = <_StatementEntry>[
      ...invoices.map((i) => _StatementEntry(
            date: i.invoice.date,
            label: 'فاتورة مبيعات #${i.invoice.id}',
            debit: i.totalUsd,
            credit: 0,
            items: i.items
                .map((d) => _StatementItemLine(
                    name: d.productName,
                    quantity: d.item.quantity,
                    unitPrice: d.item.unitPriceUsd,
                    total: d.totalUsd))
                .toList(),
          )),
      ...payments.map((p) => _StatementEntry(
            date: p.date,
            label: 'دفعة${p.notes.isNotEmpty ? ' - ${p.notes}' : ''}',
            debit: 0,
            credit: p.amountUsd,
          )),
      ...returns.map((r) => _StatementEntry(
            date: r.returnInvoice.date,
            label: 'مرتجع فاتورة #${r.returnInvoice.id}',
            debit: 0,
            credit: r.totalUsd,
            items: r.items
                .map((d) => _StatementItemLine(
                    name: d.productName,
                    quantity: d.item.quantity,
                    unitPrice: d.item.unitPriceUsd,
                    total: d.totalUsd))
                .toList(),
          )),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return _buildStatementPdf(
      title: 'كشف حساب زبون',
      partyLabel: 'الزبون',
      partyName: customerName,
      partyPhone: customerPhone,
      entries: entries,
      debitLabel: 'مدين',
      creditLabel: 'دائن',
      balanceHint: 'الرصيد الموجب = مستحق على الزبون',
      exchangeRate: exchangeRate,
    );
  }

  Future<Uint8List> buildSupplierStatementPdf({
    required String supplierName,
    required String supplierPhone,
    required List<SupplierInvoiceWithItems> invoices,
    required List<SupplierPayment> payments,
    required double exchangeRate,
  }) async {
    final entries = <_StatementEntry>[
      ...invoices.map((i) => _StatementEntry(
            date: i.invoice.date,
            label: 'فاتورة شراء #${i.invoice.id}',
            debit: i.totalUsd,
            credit: 0,
            items: i.items
                .map((d) => _StatementItemLine(
                    name: d.productName,
                    quantity: d.item.quantity,
                    unitPrice: d.item.unitPurchasePriceUsd,
                    total: d.totalUsd))
                .toList(),
          )),
      ...payments.map((p) => _StatementEntry(
            date: p.date,
            label: 'دفعة${p.notes.isNotEmpty ? ' - ${p.notes}' : ''}',
            debit: 0,
            credit: p.amountUsd,
          )),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return _buildStatementPdf(
      title: 'كشف حساب مورد',
      partyLabel: 'المورد',
      partyName: supplierName,
      partyPhone: supplierPhone,
      entries: entries,
      debitLabel: 'مدين',
      creditLabel: 'دائن',
      balanceHint: 'الرصيد الموجب = مستحق للمورد عليك',
      exchangeRate: exchangeRate,
    );
  }

  Future<Uint8List> _buildStatementPdf({
    required String title,
    required String partyLabel,
    required String partyName,
    required String partyPhone,
    required List<_StatementEntry> entries,
    required String debitLabel,
    required String creditLabel,
    required String balanceHint,
    required double exchangeRate,
  }) async {
    await _ensureFonts();
    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: _regularFont, bold: _boldFont);
    final dateFormat = DateFormat('yyyy/MM/dd');
    final timeFormat = DateFormat('HH:mm');
    final usdFormat = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    double runningBalance = 0;
    final rows = <_StatementRow>[];
    for (final e in entries) {
      runningBalance += e.debit - e.credit;
      rows.add(_StatementRow(entry: e, balanceAfter: runningBalance));
    }

    double totalDebit = entries.fold(0, (s, e) => s + e.debit);
    double totalCredit = entries.fold(0, (s, e) => s + e.credit);

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        header: (context) => context.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(kStoreName,
                              style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text(title,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  color: PdfColors.teal700,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Text(
                          'تاريخ الإصدار: ${dateFormat.format(DateTime.now())}'),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(color: PdfColors.teal200, thickness: 1.2),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.teal50,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('$partyLabel: $partyName',
                            style:
                                pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        if (partyPhone.isNotEmpty)
                          pw.Text('الهاتف: $partyPhone'),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),
                ],
              )
            : pw.SizedBox(),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('صفحة ${context.pageNumber} من ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center),
        ),
        build: (context) => [
          if (rows.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(20),
              child: pw.Center(child: pw.Text('لا توجد أي حركات مسجَّلة')),
            ),
          for (final r in rows) ...[
            _statementEntryBlock(
              r: r,
              dateFormat: dateFormat,
              timeFormat: timeFormat,
              usdFormat: usdFormat,
              debitLabel: debitLabel,
              creditLabel: creditLabel,
            ),
            pw.SizedBox(height: 8),
          ],
          pw.SizedBox(height: 8),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 260,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إجمالي $debitLabel:'),
                      pw.Text(usdFormat.format(totalDebit)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إجمالي $creditLabel:'),
                      pw.Text(usdFormat.format(totalCredit)),
                    ],
                  ),
                  pw.Divider(),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الرصيد الحالي:',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(usdFormat.format(runningBalance),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (exchangeRate > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('بالليرة السورية:',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(
                            NumberFormat.currency(symbol: 'ل.س', decimalDigits: 0)
                                .format(runningBalance * exchangeRate),
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(balanceHint,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );
    return doc.save();
  }

  /// كتلة واحدة بكشف الحساب: سطر رئيسي (تاريخ/بيان/مدين/دائن/رصيد)،
  /// وإن كانت فاتورة (بيع/شراء/مرتجع) تُدرَج تحتها تفاصيل المنتجات.
  pw.Widget _statementEntryBlock({
    required _StatementRow r,
    required DateFormat dateFormat,
    required DateFormat timeFormat,
    required NumberFormat usdFormat,
    required String debitLabel,
    required String creditLabel,
  }) {
    final hasItems = r.entry.items != null && r.entry.items!.isNotEmpty;
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const pw.BoxDecoration(color: PdfColors.teal50),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                      '${dateFormat.format(r.entry.date)}\n${timeFormat.format(r.entry.date)}',
                      style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(r.entry.label,
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                      r.entry.debit > 0 ? usdFormat.format(r.entry.debit) : '-',
                      style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                      r.entry.credit > 0 ? usdFormat.format(r.entry.credit) : '-',
                      style: const pw.TextStyle(fontSize: 10)),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(usdFormat.format(r.balanceAfter),
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (hasItems)
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(1.4),
                },
                children: [
                  for (final it in r.entry.items!)
                    pw.TableRow(children: [
                      _cell(it.name),
                      _cell(_fmtQty(it.quantity)),
                      _cell(usdFormat.format(it.unitPrice)),
                      _cell(usdFormat.format(it.total)),
                    ]),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatementItemLine {
  final String name;
  final double quantity;
  final double unitPrice;
  final double total;
  _StatementItemLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

class _StatementEntry {
  final DateTime date;
  final String label;
  final double debit;
  final double credit;
  final List<_StatementItemLine>? items;
  _StatementEntry({
    required this.date,
    required this.label,
    required this.debit,
    required this.credit,
    this.items,
  });
}

class _StatementRow {
  final _StatementEntry entry;
  final double balanceAfter;
  _StatementRow({required this.entry, required this.balanceAfter});
}

class _Row {
  final String name;
  final double quantity;
  final double unitPrice;
  final double total;
  _Row({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });
}

/// يعرض نافذة "جاري إعداد الفاتورة..." أثناء تنفيذ [task]، ويغلقها
/// تلقائياً عند الانتهاء (نجاحاً أو فشلاً). يُستخدم قبل توليد أي PDF
/// حتى لا يشعر المستخدم أن التطبيق متجمّد أثناء الإعداد.
Future<T> runWithPdfLoadingDialog<T>(
  BuildContext context,
  Future<T> Function() task,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'جاري إعداد الفاتورة...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final result = await task();
    return result;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
