import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:teknoycart/features/reports/services/seller_analytics.dart';

/// Delivery seam for the generated sales-report PDF.
///
/// Production shares the bytes through the platform share sheet (mobile) or
/// triggers a file download (web) via [Printing.sharePdf]. Tests override
/// [salesReportPdfSharerProvider] with a capturing fake so the full export
/// path can be verified without touching platform channels.
typedef SalesReportPdfSharer = Future<bool> Function(
  Uint8List bytes,
  String filename,
);

final salesReportPdfSharerProvider = Provider<SalesReportPdfSharer>(
  (ref) => (bytes, filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename),
);

// ── Brand palette (byte-mirrors TeknoyTheme so the PDF matches the app) ──
const _maroon = PdfColor.fromInt(0xFF800000);
const _gold = PdfColor.fromInt(0xFFF5B041);
const _ink = PdfColor.fromInt(0xFF1F1F24);
const _muted = PdfColor.fromInt(0xFF6B6B76);
const _line = PdfColor.fromInt(0xFFE0E0E6);
const _headerFill = PdfColor.fromInt(0xFFF3F3F6);
const _oddRowFill = PdfColor.fromInt(0xFFFAFAFC);

/// `PHP 1,234.50` — uses "PHP" instead of "₱" because PDF base fonts
/// (Helvetica) cannot encode the peso sign; anything else would render as a
/// blank/missing glyph in the exported document.
String formatPdfMoney(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final dot = fixed.indexOf('.');
  final whole = fixed.substring(0, dot);
  final cents = fixed.substring(dot + 1);
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  return 'PHP ${negative ? '-' : ''}$grouped.$cents';
}

/// `PAYMENT_VERIFIED` → `Payment Verified` — the log reads as prose instead
/// of leaking raw database enums into an exported document.
String humanizeOrderStatus(String status) {
  return status
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ')
      .trim();
}

/// PDF base fonts only encode a subset of Latin-1 and cannot draw most
/// typography. Normalize the common cases to ASCII and replace the rest so
/// an exotic listing name can never produce a blank/missing glyph in the
/// exported document.
String _safe(String? raw) {
  var s = raw ?? '';
  if (s.isEmpty) return s;
  s = s
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2022', '*')
      .replaceAll('\u2026', '...');
  return s.replaceAll(RegExp(r'[^\u0000-\u00ff]'), '?');
}

double _asDouble(Object? value) =>
    value is num ? value.toDouble() : (double.tryParse(value?.toString() ?? '') ?? 0.0);

int _asInt(Object? value) =>
    value is num ? value.toInt() : (int.tryParse(value?.toString() ?? '') ?? 0);

String _two(int v) => v.toString().padLeft(2, '0');

String _formatDateTime(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';

/// Builds the seller-facing sales report PDF for the selected [period] from
/// the same [summary] map the dashboard renders. Pure Dart — no network,
/// assets or platform channels — so it is unit-testable end to end.
Future<Uint8List> buildSalesReportPdf({
  required String sellerName,
  required String period,
  required Map<String, dynamic> summary,
  DateTime? generatedAt,
}) async {
  final now = generatedAt ?? DateTime.now();
  final revenue = _asDouble(summary['revenue']);
  final count = _asInt(summary['count']);
  final inquiries = _asInt(summary['inquiries']);
  final ordersPlaced = _asInt(summary['ordersPlaced']);
  final seller = _safe(sellerName.isEmpty ? 'Seller' : sellerName);

  final txns = <Map<String, dynamic>>[
    for (final t in (summary['txns'] as List<dynamic>? ?? const []))
      if (t is Map) Map<String, dynamic>.from(t),
  ];
  final topProducts = (summary['topProducts'] as List<dynamic>? ?? const [])
      .whereType<TopProductStat>()
      .toList();
  final lowStock = (summary['lowStock'] as List<dynamic>? ?? const [])
      .whereType<LowStockAlert>()
      .toList();
  final categories = <(String, double)>[
    ('Books', _asDouble(summary['books'])),
    ('Drawing Tools', _asDouble(summary['drawing'])),
    ('Uniforms', _asDouble(summary['uniforms'])),
    ('Electronics', _asDouble(summary['electronics'])),
    ('Others', _asDouble(summary['others'])),
  ];
  final funnel = SalesFunnel(
    inquiries: inquiries,
    ordersPlaced: ordersPlaced,
    confirmed: count,
  );

  final doc = pw.Document(
    title: 'TeknoyCart Sales Report - $period',
    author: 'TeknoyCart',
    creator: 'TeknoyCart Seller Analytics',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TeknoyCart Sales Report · $seller',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      ),
      build: (ctx) => [
        _reportHeader(seller, period, now),
        _sectionTitle('Sales Summary'),
        pw.Row(
          children: [
            _kpiBox('Total Revenue', formatPdfMoney(revenue)),
            _kpiBox('Transactions', '$count'),
            _kpiBox('Inquiries', '$inquiries'),
            _kpiBox('Orders Placed', '$ordersPlaced'),
          ],
        ),
        _sectionTitle('Conversion Funnel'),
        _table(
          headers: const ['Stage', 'Count', 'Conversion'],
          rows: [
            ['Inquiries', '$inquiries', '-'],
            [
              'Orders Placed',
              '$ordersPlaced',
              '${(funnel.inquiryToOrderRate * 100).toStringAsFixed(0)}% of inquiries',
            ],
            [
              'Confirmed Sales',
              '$count',
              '${(funnel.orderToConfirmRate * 100).toStringAsFixed(0)}% of orders',
            ],
          ],
          widths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
          },
          aligns: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
        ),
        _sectionTitle('Revenue by Category'),
        _table(
          headers: const ['Category', 'Revenue', 'Share'],
          rows: [
            for (final (name, value) in categories)
              [
                name,
                formatPdfMoney(value),
                revenue > 0 ? '${(value / revenue * 100).toStringAsFixed(1)}%' : '-',
              ],
          ],
          widths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.4),
            2: const pw.FlexColumnWidth(1),
          },
          aligns: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
          },
        ),
        _sectionTitle('Top Products'),
        if (topProducts.isEmpty)
          _emptyNote('No confirmed sales in this period yet.')
        else
          _table(
            headers: const ['Product', 'Orders', 'Units', 'Revenue'],
            rows: [
              for (final p in topProducts)
                [_safe(p.name), '${p.orders}', '${p.units}', formatPdfMoney(p.revenue)],
            ],
            widths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.4),
            },
            aligns: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
        _sectionTitle('Low Stock Alerts'),
        if (lowStock.isEmpty)
          _emptyNote('All tracked inventory levels are above their alert thresholds.')
        else
          _table(
            headers: const ['Product', 'Variant', 'SKU', 'Stock', 'Threshold'],
            rows: [
              for (final a in lowStock)
                [
                  _safe(a.productName),
                  _safe(a.variantLabel),
                  _safe(a.sku),
                  '${a.stockQty}',
                  '${a.threshold}',
                ],
            ],
            widths: {
              0: const pw.FlexColumnWidth(2.6),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(0.8),
              4: const pw.FlexColumnWidth(1),
            },
            aligns: {
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
        _sectionTitle('Transaction Log'),
        if (txns.isEmpty)
          _emptyNote('No orders in this period.')
        else
          _table(
            headers: const ['Transaction', 'Item', 'Amount', 'Date', 'Status'],
            rows: [
              for (final t in txns)
                [
                  _safe(t['id']?.toString()),
                  _safe(t['item']?.toString()),
                  formatPdfMoney(_asDouble(t['amount'])),
                  _safe(t['date']?.toString()),
                  _safe(humanizeOrderStatus(t['status']?.toString() ?? '')),
                ],
            ],
            widths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.1),
              3: const pw.FlexColumnWidth(1.1),
              4: const pw.FlexColumnWidth(1.3),
            },
            aligns: {
              2: pw.Alignment.centerRight,
            },
          ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _reportHeader(String seller, String period, DateTime now) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _maroon,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TEKNOYCART',
              style: const pw.TextStyle(
                color: _gold,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Sales Report',
              style: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              seller,
              style: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              '$period · Generated ${_formatDateTime(now)}',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
    child: pw.Text(
      text,
      style: const pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
    ),
  );
}

pw.Widget _kpiBox(String label, String value) {
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 3),
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: _headerFill,
        border: pw.Border.all(color: _line, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _maroon,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
    ),
  );
}

pw.Widget _table({
  required List<dynamic> headers,
  required List<List<dynamic>> rows,
  required Map<int, pw.TableColumnWidth> widths,
  Map<int, pw.AlignmentGeometry> aligns = const {},
}) {
  // Every string cell is sanitized centrally so no table can ever render a
  // blank glyph, regardless of what the data layer hands us.
  dynamic sanitize(dynamic cell) => cell is String ? _safe(cell) : cell;

  return pw.TableHelper.fromTextArray(
    headers: [for (final h in headers) sanitize(h)],
    data: [
      for (final row in rows) [for (final cell in row) sanitize(cell)],
    ],
    columnWidths: widths,
    headerDecoration: const pw.BoxDecoration(color: _headerFill),
    oddRowDecoration: const pw.BoxDecoration(color: _oddRowFill),
    headerStyle: const pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
    cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
    headerAlignment: pw.Alignment.centerLeft,
    headerAlignments: aligns,
    cellAlignments: aligns,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    border: pw.TableBorder.all(color: _line, width: 0.5),
    tableWidth: pw.TableWidth.max,
  );
}

pw.Widget _emptyNote(String text) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _line, width: 0.5),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Text(_safe(text),
        style: const pw.TextStyle(fontSize: 9, color: _muted)),
  );
}
