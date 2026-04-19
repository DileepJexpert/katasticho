import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Full-screen PDF preview for a single delivery challan.
///
/// Receives the raw challan [data] map — same payload as
/// [deliveryChallanDetailProvider] returns — and generates a professional PDF
/// on the fly using the `pdf` package. The `printing` package's [PdfPreview]
/// widget handles both mobile share sheets and the browser's built-in PDF
/// viewer on Flutter Web.
class DeliveryChallanPdfScreen extends StatelessWidget {
  final Map<String, dynamic> challan;

  const DeliveryChallanPdfScreen({super.key, required this.challan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            challan['challanNumber'] as String? ?? 'Delivery Challan Preview'),
      ),
      body: PdfPreview(
        build: (format) => _buildPdf(format, challan),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName:
            '${challan['challanNumber'] ?? 'challan'}.pdf',
      ),
    );
  }
}

Future<Uint8List> _buildPdf(
    PdfPageFormat format, Map<String, dynamic> ch) async {
  final doc = pw.Document(compress: true);

  // ── Pull data ──────────────────────────────────────────────────
  final challanNumber = ch['challanNumber'] as String? ?? '--';
  final contactName = ch['contactName'] as String? ?? '--';
  final challanDate = ch['challanDate'] as String? ?? '--';
  final dispatchDate = ch['dispatchDate'] as String?;
  final status = ch['status'] as String? ?? 'DRAFT';
  final salesOrderNumber = ch['salesOrderNumber'] as String?;
  final vehicleNumber = ch['vehicleNumber'] as String?;
  final trackingNumber = ch['trackingNumber'] as String?;
  final deliveryMethod = ch['deliveryMethod'] as String?;
  final lines = (ch['lines'] as List?) ?? [];

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
                pw.Text('DELIVERY CHALLAN',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: primary,
                      letterSpacing: 2,
                    )),
                pw.SizedBox(height: 4),
                pw.Text(challanNumber,
                    style: pw.TextStyle(
                        fontSize: 14, color: textMuted)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _badgeWidget(status),
                pw.SizedBox(height: 8),
                _labelValue('Challan Date', challanDate),
                if (dispatchDate != null)
                  _labelValue('Dispatch Date', dispatchDate),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 24),
        pw.Divider(color: border),
        pw.SizedBox(height: 16),

        // ── Ship To ─────────────────────────────────────────────
        pw.Text('SHIP TO',
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

        pw.SizedBox(height: 16),

        // ── Shipping details ────────────────────────────────────
        pw.Wrap(
          spacing: 24,
          runSpacing: 4,
          children: [
            if (salesOrderNumber != null)
              _labelValue('Sales Order', salesOrderNumber),
            if (deliveryMethod != null)
              _labelValue('Delivery Method', deliveryMethod),
            if (vehicleNumber != null)
              _labelValue('Vehicle No.', vehicleNumber),
            if (trackingNumber != null)
              _labelValue('Tracking No.', trackingNumber),
          ],
        ),

        pw.SizedBox(height: 24),

        // ── Line items table ─────────────────────────────────────
        pw.Table(
          border: pw.TableBorder(
            bottom: const pw.BorderSide(color: border),
            horizontalInside: const pw.BorderSide(
                color: border, width: 0.5),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FixedColumnWidth(60),
            3: const pw.FixedColumnWidth(60),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: primary),
              children: [
                _headerCell('ITEM'),
                _headerCell('DESCRIPTION'),
                _headerCell('QTY', align: pw.TextAlign.right),
                _headerCell('UNIT', align: pw.TextAlign.right),
              ],
            ),
            // Data rows
            ...lines.asMap().entries.map((entry) {
              final i = entry.key;
              final line = entry.value as Map<String, dynamic>;
              final itemName =
                  line['itemName'] as String? ?? '--';
              final description =
                  line['description'] as String? ?? '';
              final qty =
                  (line['quantity'] as num?)?.toDouble() ?? 0;
              final unit = line['unit'] as String? ?? '--';
              final batchNumber =
                  line['batchNumber'] as String?;

              // Append batch number to description if present
              final descDisplay = batchNumber != null &&
                      batchNumber.isNotEmpty
                  ? description.isNotEmpty
                      ? '$description\nBatch: $batchNumber'
                      : 'Batch: $batchNumber'
                  : description.isNotEmpty
                      ? description
                      : '--';

              return pw.TableRow(
                decoration: pw.BoxDecoration(
                    color: i.isOdd ? rowAlt : PdfColors.white),
                children: [
                  _dataCell(itemName),
                  _dataCell(descDisplay),
                  _dataCell(
                      qty.toStringAsFixed(
                          qty.truncateToDouble() == qty ? 0 : 2),
                      align: pw.TextAlign.right),
                  _dataCell(unit, align: pw.TextAlign.right),
                ],
              );
            }),
          ],
        ),

        pw.SizedBox(height: 40),

        // ── Footer ────────────────────────────────────────────────
        pw.Text(
          'This is a computer-generated delivery challan.',
          style: pw.TextStyle(
              fontSize: 10,
              color: textMuted,
              fontStyle: pw.FontStyle.italic),
        ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

// ── Helper builders ────────────────────────────────────────────────────────────

pw.Widget _badgeWidget(String status) {
  final colors = {
    'DRAFT': PdfColor.fromInt(0xFF94A3B8),
    'DISPATCHED': PdfColor.fromInt(0xFF3B82F6),
    'DELIVERED': PdfColor.fromInt(0xFF10B981),
    'CANCELLED': PdfColor.fromInt(0xFFEF4444),
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
