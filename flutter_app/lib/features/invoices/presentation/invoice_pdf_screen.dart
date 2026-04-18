import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Full-screen PDF preview for a single invoice.
///
/// Receives the raw invoice [data] map — same payload as [invoiceDetailProvider]
/// returns — and generates a professional PDF on the fly using the `pdf` package.
/// The `printing` package's [PdfPreview] widget handles both mobile share sheets
/// and the browser's built-in PDF viewer on Flutter Web.
class InvoicePdfScreen extends StatelessWidget {
  final Map<String, dynamic> invoice;

  const InvoicePdfScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            invoice['invoiceNumber'] as String? ?? 'Invoice Preview'),
      ),
      body: PdfPreview(
        build: (format) => _buildPdf(format, invoice),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName:
            '${invoice['invoiceNumber'] ?? 'invoice'}.pdf',
      ),
    );
  }
}

Future<List<int>> _buildPdf(
    PdfPageFormat format, Map<String, dynamic> inv) async {
  final doc = pw.Document(compress: true);

  // ── Pull data ──────────────────────────────────────────────────
  final invoiceNumber = inv['invoiceNumber'] as String? ?? '--';
  final contactName = inv['contactName'] as String? ?? '--';
  final invoiceDate = inv['invoiceDate'] as String? ?? '--';
  final dueDate = inv['dueDate'] as String? ?? '--';
  final status = inv['status'] as String? ?? 'DRAFT';
  final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
  final taxTotal = (inv['taxTotal'] as num?)?.toDouble() ?? 0;
  final total = (inv['total'] as num?)?.toDouble() ?? 0;
  final balanceDue = (inv['balanceDue'] as num?)?.toDouble() ?? total;
  final lines = (inv['lines'] as List?) ?? [];

  // ── Colours ───────────────────────────────────────────────────
  const primary = PdfColor.fromInt(0xFF2563EB); // Katasticho blue
  const textDark = PdfColor.fromInt(0xFF0F172A);
  const textMuted = PdfColor.fromInt(0xFF64748B);
  const border = PdfColor.fromInt(0xFFE2E8F0);
  const rowAlt = PdfColor.fromInt(0xFFF8FAFC);

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        // ── Header ──────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('INVOICE',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: primary,
                      letterSpacing: 2,
                    )),
                pw.SizedBox(height: 4),
                pw.Text(invoiceNumber,
                    style: pw.TextStyle(
                        fontSize: 14, color: textMuted)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _badgeWidget(status),
                pw.SizedBox(height: 8),
                _labelValue('Invoice Date', invoiceDate),
                _labelValue('Due Date', dueDate),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Divider(color: border),
        pw.SizedBox(height: 16),

        // ── Bill To ─────────────────────────────────────────────
        pw.Text('BILL TO',
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

        // ── Line items table ─────────────────────────────────────
        pw.Table(
          border: pw.TableBorder(
            bottom: const pw.BorderSide(color: border),
            horizontalInside: const pw.BorderSide(
                color: border, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FixedColumnWidth(60),
            2: const pw.FixedColumnWidth(80),
            3: const pw.FixedColumnWidth(80),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: primary),
              children: [
                _headerCell('DESCRIPTION'),
                _headerCell('QTY', align: pw.TextAlign.right),
                _headerCell('UNIT PRICE',
                    align: pw.TextAlign.right),
                _headerCell('AMOUNT',
                    align: pw.TextAlign.right),
              ],
            ),
            // Data rows
            ...lines.asMap().entries.map((entry) {
              final i = entry.key;
              final line = entry.value as Map<String, dynamic>;
              final desc =
                  line['description'] as String? ?? '--';
              final qty =
                  (line['quantity'] as num?)?.toDouble() ?? 0;
              final price =
                  (line['unitPrice'] as num?)?.toDouble() ?? 0;
              final amount =
                  (line['lineTotal'] as num?)?.toDouble()
                      ?? qty * price;

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? rowAlt : PdfColors.white),
                children: [
                  _dataCell(desc),
                  _dataCell(
                      qty.toStringAsFixed(
                          qty.truncateToDouble() == qty ? 0 : 2),
                      align: pw.TextAlign.right),
                  _dataCell(_fmt(price),
                      align: pw.TextAlign.right),
                  _dataCell(_fmt(amount),
                      align: pw.TextAlign.right),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 16),

        // ── Totals ───────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 220,
              child: pw.Column(
                children: [
                  _totalRow('Subtotal', _fmt(subtotal)),
                  if (taxTotal > 0)
                    _totalRow('Tax', _fmt(taxTotal)),
                  pw.Divider(color: border),
                  _totalRow('Total', _fmt(total),
                      bold: true, large: true),
                  if (balanceDue > 0 && balanceDue < total)
                    _totalRow(
                      'Balance Due',
                      _fmt(balanceDue),
                      color: PdfColor.fromInt(0xFFEF4444),
                      bold: true,
                    ),
                ],
              ),
            ),
          ],
        ),

        pw.SizedBox(height: 40),

        // ── Footer ────────────────────────────────────────────────
        pw.Text(
          'Thank you for your business.',
          style: pw.TextStyle(
              fontSize: 10,
              color: textMuted,
              fontStyle: pw.FontStyle.italic),
        ),
      ],
    ),
  );

  return doc.save();
}

// ── Helper builders ────────────────────────────────────────────────────────────

pw.Widget _badgeWidget(String status) {
  final colors = {
    'DRAFT': PdfColor.fromInt(0xFF94A3B8),
    'SENT': PdfColor.fromInt(0xFF3B82F6),
    'PAID': PdfColor.fromInt(0xFF10B981),
    'OVERDUE': PdfColor.fromInt(0xFFEF4444),
    'PARTIALLY_PAID': PdfColor.fromInt(0xFFF59E0B),
  };
  final c = colors[status] ?? PdfColor.fromInt(0xFF64748B);
  return pw.Container(
    padding:
        const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: pw.BoxDecoration(
      color: c,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Text(
      status.replaceAll('_', ' '),
      style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _labelValue(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromInt(0xFF64748B))),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF0F172A))),
        ],
      ),
    );

pw.Widget _headerCell(String text,
        {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
          letterSpacing: 0.8,
        ),
        textAlign: align,
      ),
    );

pw.Widget _dataCell(String text,
        {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
            fontSize: 10, color: PdfColor.fromInt(0xFF0F172A)),
        textAlign: align,
      ),
    );

pw.Widget _totalRow(String label, String value,
    {bool bold = false,
    bool large = false,
    PdfColor color = const PdfColor.fromInt(0xFF0F172A)}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: large ? 12 : 10,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: const PdfColor.fromInt(0xFF64748B))),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: large ? 13 : 10,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );

String _fmt(double v) => '₹${v.toStringAsFixed(2)}';
