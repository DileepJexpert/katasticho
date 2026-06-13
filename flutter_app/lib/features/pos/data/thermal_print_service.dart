import 'dart:async';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSavedPrinterKey = 'thermal_printer_id';
const _kSavedPrinterNameKey = 'thermal_printer_name';
const _kAutoPrintKey = 'receipt_autoPrint';

class ThermalPrintService {
  ThermalPrintService._();
  static final instance = ThermalPrintService._();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeChar;
  bool _connecting = false;

  bool get isConnected => _connectedDevice != null && _writeChar != null;
  String? get connectedPrinterName => _connectedDevice?.platformName;

  Future<bool> get autoPrintEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAutoPrintKey) ?? false;
  }

  Future<void> setAutoPrint(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoPrintKey, value);
  }

  Future<String?> get savedPrinterId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSavedPrinterKey);
  }

  Future<String?> get savedPrinterName async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSavedPrinterNameKey);
  }

  Future<void> _savePrinter(BluetoothDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSavedPrinterKey, device.remoteId.str);
    await prefs.setString(_kSavedPrinterNameKey,
        device.platformName.isNotEmpty ? device.platformName : device.remoteId.str);
  }

  Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSavedPrinterKey);
    await prefs.remove(_kSavedPrinterNameKey);
    await disconnect();
  }

  Future<List<ScanResult>> scanForPrinters({Duration timeout = const Duration(seconds: 4)}) async {
    final results = <ScanResult>[];

    if (!await FlutterBluePlus.isSupported) {
      throw Exception('Bluetooth is not supported on this device');
    }

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      throw Exception('Bluetooth is turned off');
    }

    final completer = Completer<List<ScanResult>>();
    final sub = FlutterBluePlus.scanResults.listen((scanResults) {
      results.clear();
      results.addAll(scanResults.where((r) => r.device.platformName.isNotEmpty));
    });

    await FlutterBluePlus.startScan(timeout: timeout);
    await Future.delayed(timeout + const Duration(milliseconds: 500));
    sub.cancel();

    if (!completer.isCompleted) {
      completer.complete(results);
    }
    return results;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (_connecting) return false;
    _connecting = true;

    try {
      await disconnect();
      await device.connect(timeout: const Duration(seconds: 5));

      final services = await device.discoverServices();
      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.writeWithoutResponse || char.properties.write) {
            _writeChar = char;
            _connectedDevice = device;
            await _savePrinter(device);
            return true;
          }
        }
      }
      await device.disconnect();
      return false;
    } catch (e) {
      debugPrint('[ThermalPrint] Connect failed: $e');
      return false;
    } finally {
      _connecting = false;
    }
  }

  Future<bool> reconnectSaved() async {
    final id = await savedPrinterId;
    if (id == null) return false;
    if (isConnected && _connectedDevice?.remoteId.str == id) return true;

    try {
      final device = BluetoothDevice.fromId(id);
      return await connectToDevice(device);
    } catch (e) {
      debugPrint('[ThermalPrint] Reconnect failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    _writeChar = null;
  }

  Future<void> printBytes(List<int> bytes) async {
    if (_writeChar == null) throw Exception('No printer connected');

    const chunkSize = 200;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
      final chunk = bytes.sublist(i, end);
      await _writeChar!.write(
        Uint8List.fromList(chunk),
        withoutResponse: _writeChar!.properties.writeWithoutResponse,
      );
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> printReceipt({
    required Map<String, dynamic> receipt,
    required Map<String, dynamic> org,
    required ReceiptPrintSettings settings,
  }) async {
    final bytes = await _buildReceiptBytes(receipt, org, settings);
    await printBytes(bytes);
  }

  Future<List<int>> _buildReceiptBytes(
    Map<String, dynamic> receipt,
    Map<String, dynamic> org,
    ReceiptPrintSettings settings,
  ) async {
    final paper = settings.paperSize == '80mm' ? PaperSize.mm80 : PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    final gen = Generator(paper, profile);
    List<int> bytes = [];

    bytes += gen.reset();

    // Store name
    final orgName = org['name']?.toString() ?? '';
    if (orgName.isNotEmpty) {
      bytes += gen.text(orgName,
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += gen.emptyLines(1);
    }

    // Store address
    if (settings.showStoreAddress) {
      final addr = org['address']?.toString() ?? '';
      if (addr.isNotEmpty) {
        bytes += gen.text(addr, styles: const PosStyles(align: PosAlign.center));
      }
      final phone = org['phone']?.toString() ?? '';
      if (phone.isNotEmpty) {
        bytes += gen.text('Ph: $phone', styles: const PosStyles(align: PosAlign.center));
      }
    }

    // GSTIN
    if (settings.showGstin) {
      final gstin = org['gstin']?.toString() ?? '';
      if (gstin.isNotEmpty) {
        bytes += gen.text('GSTIN: $gstin', styles: const PosStyles(align: PosAlign.center));
      }
    }

    bytes += gen.hr();

    // Receipt number + date
    final receiptNumber = receipt['receiptNumber']?.toString() ?? '';
    final receiptDate = receipt['receiptDate']?.toString() ?? '';
    bytes += gen.text('Bill: $receiptNumber',
        styles: const PosStyles(bold: true));
    bytes += gen.text('Date: ${_formatDate(receiptDate)}');

    // Customer
    final contactName = receipt['contactName']?.toString() ?? '';
    if (contactName.isNotEmpty) {
      bytes += gen.text('Customer: $contactName');
    }

    bytes += gen.hr(ch: '-');

    // Column header
    if (paper == PaperSize.mm80) {
      bytes += gen.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Rate', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Amt', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
    } else {
      bytes += gen.row([
        PosColumn(text: 'Item', width: 7, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Amt', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
    }
    bytes += gen.hr(ch: '-');

    // Line items
    final lines = (receipt['lines'] as List<dynamic>?) ?? [];
    for (final line in lines) {
      final name = (line['itemName'] ?? line['description'] ?? '').toString();
      final qty = _num(line['quantity']);
      final rate = _num(line['rate']);
      final amount = _num(line['amount']);
      final unit = line['unit']?.toString() ?? 'PCS';

      if (paper == PaperSize.mm80) {
        final displayName = name.length > 22 ? name.substring(0, 22) : name;
        bytes += gen.row([
          PosColumn(text: displayName, width: 6),
          PosColumn(text: '${_fmtQty(qty)}$unit', width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: _fmtAmt(rate), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: _fmtAmt(amount), width: 2, styles: const PosStyles(align: PosAlign.right)),
        ]);
      } else {
        if (name.length > 16) {
          bytes += gen.text(name);
          bytes += gen.row([
            PosColumn(text: '', width: 7),
            PosColumn(text: '${_fmtQty(qty)}$unit', width: 2, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: _fmtAmt(amount), width: 3, styles: const PosStyles(align: PosAlign.right)),
          ]);
        } else {
          bytes += gen.row([
            PosColumn(text: name, width: 7),
            PosColumn(text: '${_fmtQty(qty)}$unit', width: 2, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: _fmtAmt(amount), width: 3, styles: const PosStyles(align: PosAlign.right)),
          ]);
        }
      }

      if (settings.showHsnCode) {
        final hsn = line['hsnCode']?.toString() ?? '';
        if (hsn.isNotEmpty) {
          bytes += gen.text('  HSN: $hsn', styles: const PosStyles(fontType: PosFontType.fontB));
        }
      }
    }

    bytes += gen.hr(ch: '-');

    // Totals
    final subtotal = _num(receipt['subtotal']);
    final cgst = _num(receipt['cgst']);
    final sgst = _num(receipt['sgst']);
    final igst = _num(receipt['igst']);
    final total = _num(receipt['total']);
    final discount = _num(receipt['discountTotal']);

    bytes += _totalRow(gen, 'Subtotal', subtotal);
    if (discount > 0) {
      bytes += _totalRow(gen, 'Discount', -discount);
    }
    if (settings.showTaxBreakdown) {
      if (cgst > 0) bytes += _totalRow(gen, 'CGST', cgst);
      if (sgst > 0) bytes += _totalRow(gen, 'SGST', sgst);
      if (igst > 0) bytes += _totalRow(gen, 'IGST', igst);
    }
    bytes += gen.hr(ch: '-');
    bytes += gen.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(text: _fmtAmt(total), width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
    ]);

    // Payment info
    final paymentMode = receipt['paymentMode']?.toString() ?? 'CASH';
    final amountReceived = _num(receipt['amountReceived']);
    final changeReturned = _num(receipt['changeReturned']);

    bytes += gen.emptyLines(1);
    bytes += gen.text('Paid: $paymentMode  ${_fmtAmt(amountReceived)}',
        styles: const PosStyles(align: PosAlign.center));
    if (changeReturned > 0) {
      bytes += gen.text('Change: ${_fmtAmt(changeReturned)}',
          styles: const PosStyles(align: PosAlign.center));
    }

    bytes += gen.hr();

    // Footer
    if (settings.footerText.isNotEmpty) {
      bytes += gen.text(settings.footerText,
          styles: const PosStyles(align: PosAlign.center));
    }

    bytes += gen.emptyLines(1);
    bytes += gen.cut();

    return bytes;
  }

  List<int> _totalRow(Generator gen, String label, double amount) {
    return gen.row([
      PosColumn(text: label, width: 6),
      PosColumn(text: _fmtAmt(amount.abs()), width: 6,
          styles: PosStyles(align: PosAlign.right,
              bold: label == 'TOTAL')),
    ]);
  }

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

  static String _fmtAmt(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class ReceiptPrintSettings {
  final String paperSize;
  final bool showStoreAddress;
  final bool showGstin;
  final bool showHsnCode;
  final bool showTaxBreakdown;
  final String footerText;

  const ReceiptPrintSettings({
    this.paperSize = '58mm',
    this.showStoreAddress = true,
    this.showGstin = true,
    this.showHsnCode = false,
    this.showTaxBreakdown = true,
    this.footerText = 'Thank you for your purchase!',
  });
}
