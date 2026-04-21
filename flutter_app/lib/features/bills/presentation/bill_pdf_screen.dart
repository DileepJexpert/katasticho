import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BillPdfScreen extends StatelessWidget {
  final Map<String, dynamic> bill;

  const BillPdfScreen({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(bill['billNumber'] as String? ?? 'Bill Preview'),
      ),
      body: PdfPreview(
        build: (format) => _buildPdf(format, bill),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: '${bill['billNumber'] ?? 'bill'}.pdf',
      ),
    );
  }
}

Future<Uint8List> _buildPdf(
    PdfPageFormat format, Map<String, dynamic> b) async {
  final doc = pw.Document(compress: true);

  final billNumber = b['billNumber'] as String? ?? '--';
  final vendorName = b['vendorName'] as String? ?? '--';
  final vendorBillNumber = b['vendorBillNumber'] as String?;
  final billDate = b['billDate'] as String? ?? '--';
  final dueDate = b['dueDate'] as String?;
  final status = b['status'] as String? ?? 'DRAFT';
  final subtotal = (b['subtotal'] as num?)?.toDouble() ?? 0;
  final taxAmount = (b['taxAmount'] as num?)?.toDouble() ?? 0;
  final totalAmount = (b['totalAmount'] as num?)?.toDouble() ?? 0;
  final amountPaid = (b['amountPaid'] as num?)?.toDouble() ?? 0;
  final balanceDue = (b['balanceDue'] as num?)?.toDouble() ?? totalAmount;
  final lines = (b['lines'] as List?) ?? [];

  const slate = PdfColor.fromInt(0xFF475569);
  const textDark = PdfColor.fromInt(0xFF0F172A);
  const textMuted = PdfColor.fromInt(0xFF64748B);
  const border = PdfColor.fromInt(0xFFE2E8F0);
  const rowAlt = PdfColor.fromInt(0xFFF8FAFC);

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        // ── Header ───────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PURCHASE BILL',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: slate,
                      letterSpacing: 1.5,
                    )),
                pw.SizedBox(height: 4),
                pw.Text(billNumber,
                    style: pw.TextStyle(fontSize: 14, color: textMuted)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _badgeWidget(status),
                pw.SizedBox(height: 8),
                _labelValue('Bill Date', billDate),
                if (dueDate != null) _labelValue('Due Date', dueDate),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Divider(color: border),
        pw.SizedBox(height: 16),

        // ── Vendor ───────────────────────────────────────────────
        pw.Text('VENDOR',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: textMuted,
              letterSpacing: 1.5,
            )),
        pw.SizedBox(height: 4),
        pw.Text(vendorName,
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: textDark)),
        if (vendorBillNumber != null && vendorBillNumber.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text('Ref: $vendorBillNumber',
              style: pw.TextStyle(fontSize: 9, color: textMuted)),
        ],

        pw.SizedBox(height: 24),

        // ── Line items table ─────────────────────────────────────
        pw.Table(
          border: pw.TableBorder(
            bottom: const pw.BorderSide(color: border),
            horizontalInside:
                const pw.BorderSide(color: border, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FixedColumnWidth(55),
            2: const pw.FixedColumnWidth(55),
            3: const pw.FixedColumnWidth(40),
            4: const pw.FixedColumnWidth(75),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: slate),
              children: [
                _headerCell('DESCRIPTION'),
                _headerCell('HSN/SAC', align: pw.TextAlign.center),
                _headerCell('QTY', align: pw.TextAlign.right),
                _headerCell('GST', align: pw.TextAlign.right),
                _headerCell('AMOUNT', align: pw.TextAlign.right),
              ],
            ),
            ...lines.asMap().entries.map((e) {
              final i = e.key;
              final line = e.value as Map<String, dynamic>;
              final desc = line['description'] as String? ?? '--';
              final hsn = line['hsnCode'] as String? ?? '';
              final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
              final gstRate = line['gstRate'];
              final lineTotal =
                  (line['lineTotal'] as num?)?.toDouble() ?? 0;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? rowAlt : PdfColors.white),
                children: [
                  _dataCell(desc),
                  _dataCell(hsn, align: pw.TextAlign.center),
                  _dataCell(
                      qty.toStringAsFixed(
                          qty.truncateToDouble() == qty ? 0 : 2),
                      align: pw.TextAlign.right),
                  _dataCell(
                      gstRate != null ? '$gstRate%' : '',
                      align: pw.TextAlign.right),
                  _dataCell(_fmt(lineTotal),
                      align: pw.TextAlign.right),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 16),

        // ── Totals ───────────────────────────────────────────────
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 220,
            child: pw.Column(
              children: [
                _totalRow('Subtotal', _fmt(subtotal),
                    color: textMuted),
                if (taxAmount > 0)
                  _totalRow('Tax', _fmt(taxAmount), color: textMuted),
                pw.Divider(color: border, height: 10),
                _totalRow('Total', _fmt(totalAmount), bold: true),
                if (amountPaid > 0)
                  _totalRow('Amount Paid', _fmt(amountPaid),
                      color: textMuted),
                if (balanceDue > 0)
                  _totalRow('Balance Due', _fmt(balanceDue),
                      bold: true,
                      color: const PdfColor.fromInt(0xFFDC2626)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

// ── Helpers ──────────────────────────────────────────────────────────────────

pw.Widget _badgeWidget(String status) {
  final PdfColor bg;
  final PdfColor fg;
  switch (status.toUpperCase()) {
    case 'POSTED':
      bg = const PdfColor.fromInt(0xFFDBEAFE);
      fg = const PdfColor.fromInt(0xFF1D4ED8);
      break;
    case 'PAID':
      bg = const PdfColor.fromInt(0xFFD1FAE5);
      fg = const PdfColor.fromInt(0xFF065F46);
      break;
    case 'OVERDUE':
      bg = const PdfColor.fromInt(0xFFFEE2E2);
      fg = const PdfColor.fromInt(0xFF991B1B);
      break;
    case 'PARTIALLY_PAID':
      bg = const PdfColor.fromInt(0xFFFEF3C7);
      fg = const PdfColor.fromInt(0xFF92400E);
      break;
    case 'VOID':
      bg = const PdfColor.fromInt(0xFFF1F5F9);
      fg = const PdfColor.fromInt(0xFF94A3B8);
      break;
    default:
      bg = const PdfColor.fromInt(0xFFF1F5F9);
      fg = const PdfColor.fromInt(0xFF64748B);
  }
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
        color: bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
    child: pw.Text(status.replaceAll('_', ' '),
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: fg)),
  );
}

pw.Widget _labelValue(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label: ',
            style: pw.TextStyle(
                fontSize: 9, color: const PdfColor.fromInt(0xFF64748B))),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0F172A))),
      ],
    ),
  );
}

pw.Widget _headerCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    child: pw.Text(text,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            letterSpacing: 0.4)),
  );
}

pw.Widget _dataCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    child: pw.Text(text,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: 9, color: const PdfColor.fromInt(0xFF0F172A))),
  );
}

pw.Widget _totalRow(String label, String value,
    {bool bold = false, PdfColor? color}) {
  final style = pw.TextStyle(
    fontSize: 10,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color ?? const PdfColor.fromInt(0xFF0F172A),
  );
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: style),
      pw.Text(value, style: style),
    ],
  );
}

String _fmt(double v) => '₹${v.toStringAsFixed(2)}';
