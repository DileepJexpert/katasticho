import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EstimatePdfScreen extends StatelessWidget {
  final Map<String, dynamic> estimate;

  const EstimatePdfScreen({super.key, required this.estimate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(estimate['estimateNumber'] as String? ?? 'Estimate Preview'),
      ),
      body: PdfPreview(
        build: (format) => _buildPdf(format, estimate),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: '${estimate['estimateNumber'] ?? 'estimate'}.pdf',
      ),
    );
  }
}

Future<Uint8List> _buildPdf(
    PdfPageFormat format, Map<String, dynamic> e) async {
  final doc = pw.Document(compress: true);

  final estimateNumber = e['estimateNumber'] as String? ?? '--';
  final contactName = e['contactName'] as String? ?? '--';
  final estimateDate = e['estimateDate'] as String? ?? '--';
  final expiryDate = e['expiryDate'] as String?;
  final subject = e['subject'] as String?;
  final status = e['status'] as String? ?? 'DRAFT';
  final subtotal = (e['subtotal'] as num?)?.toDouble() ?? 0;
  final taxAmount = (e['taxAmount'] as num?)?.toDouble() ?? 0;
  final total = (e['total'] as num?)?.toDouble() ?? 0;
  final lines = (e['lines'] as List?) ?? [];

  const teal = PdfColor.fromInt(0xFF0D9488);
  const textDark = PdfColor.fromInt(0xFF0F172A);
  const textMuted = PdfColor.fromInt(0xFF64748B);
  const border = PdfColor.fromInt(0xFFE2E8F0);
  const rowAlt = PdfColor.fromInt(0xFFF0FDFA);

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
                pw.Text('ESTIMATE',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: teal,
                      letterSpacing: 2,
                    )),
                pw.SizedBox(height: 4),
                pw.Text(estimateNumber,
                    style: pw.TextStyle(fontSize: 14, color: textMuted)),
                if (subject != null && subject.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(subject,
                      style:
                          pw.TextStyle(fontSize: 10, color: textMuted)),
                ],
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _badgeWidget(status),
                pw.SizedBox(height: 8),
                _labelValue('Date', estimateDate),
                if (expiryDate != null)
                  _labelValue('Valid Until', expiryDate),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Divider(color: border),
        pw.SizedBox(height: 16),

        // ── Bill To ──────────────────────────────────────────────
        pw.Text('PREPARED FOR',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: textMuted,
              letterSpacing: 1.5,
            )),
        pw.SizedBox(height: 4),
        pw.Text(contactName,
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: textDark)),

        pw.SizedBox(height: 24),

        // ── Line items ───────────────────────────────────────────
        pw.Table(
          border: pw.TableBorder(
            bottom: const pw.BorderSide(color: border),
            horizontalInside:
                const pw.BorderSide(color: border, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FixedColumnWidth(55),
            2: const pw.FixedColumnWidth(80),
            3: const pw.FixedColumnWidth(80),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: teal),
              children: [
                _headerCell('DESCRIPTION'),
                _headerCell('QTY', align: pw.TextAlign.right),
                _headerCell('UNIT PRICE', align: pw.TextAlign.right),
                _headerCell('AMOUNT', align: pw.TextAlign.right),
              ],
            ),
            ...lines.asMap().entries.map((entry) {
              final i = entry.key;
              final line = entry.value as Map<String, dynamic>;
              final desc = line['description'] as String? ?? '--';
              final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
              final price =
                  (line['unitPrice'] as num?)?.toDouble() ?? 0;
              final lineTotal =
                  (line['lineTotal'] as num?)?.toDouble() ??
                      qty * price;
              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? rowAlt : PdfColors.white),
                children: [
                  _dataCell(desc),
                  _dataCell(
                      qty.toStringAsFixed(
                          qty.truncateToDouble() == qty ? 0 : 2),
                      align: pw.TextAlign.right),
                  _dataCell(_fmt(price), align: pw.TextAlign.right),
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
                _totalRow('Subtotal', _fmt(subtotal), color: textMuted),
                if (taxAmount > 0)
                  _totalRow('Tax', _fmt(taxAmount), color: textMuted),
                pw.Divider(color: border, height: 10),
                _totalRow('Total', _fmt(total),
                    bold: true, color: teal),
              ],
            ),
          ),
        ),

        pw.SizedBox(height: 32),

        // ── Footer note ──────────────────────────────────────────
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF0FDFA),
            border: pw.Border(
              left: pw.BorderSide(
                  color: PdfColor.fromInt(0xFF0D9488), width: 3),
            ),
          ),
          child: pw.Text(
            'This is an estimate only. Prices are subject to change until a formal invoice is issued.',
            style: pw.TextStyle(fontSize: 8, color: textMuted),
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
    case 'SENT':
      bg = const PdfColor.fromInt(0xFFCCFBF1);
      fg = const PdfColor.fromInt(0xFF0D9488);
      break;
    case 'ACCEPTED':
      bg = const PdfColor.fromInt(0xFFD1FAE5);
      fg = const PdfColor.fromInt(0xFF065F46);
      break;
    case 'DECLINED':
      bg = const PdfColor.fromInt(0xFFFEE2E2);
      fg = const PdfColor.fromInt(0xFF991B1B);
      break;
    case 'EXPIRED':
      bg = const PdfColor.fromInt(0xFFFEF3C7);
      fg = const PdfColor.fromInt(0xFF92400E);
      break;
    default:
      bg = const PdfColor.fromInt(0xFFF1F5F9);
      fg = const PdfColor.fromInt(0xFF64748B);
  }
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
        color: bg,
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(4))),
    child: pw.Text(status.replaceAll('_', ' '),
        style: pw.TextStyle(
            fontSize: 8, fontWeight: pw.FontWeight.bold, color: fg)),
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
                fontSize: 9,
                color: const PdfColor.fromInt(0xFF64748B))),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor.fromInt(0xFF0F172A))),
      ],
    ),
  );
}

pw.Widget _headerCell(String text,
    {pw.TextAlign align = pw.TextAlign.left}) {
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

pw.Widget _dataCell(String text,
    {pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
    child: pw.Text(text,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: 9,
            color: const PdfColor.fromInt(0xFF0F172A))),
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
