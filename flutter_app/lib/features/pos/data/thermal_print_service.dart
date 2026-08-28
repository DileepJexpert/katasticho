import 'dart:async';
import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSavedPrinterKey = 'thermal_printer_id';
const _kSavedPrinterNameKey = 'thermal_printer_name';
const _kAutoPrintKey = 'receipt_autoPrint';
const _kConnectionTypeKey = 'receipt_connectionType';
const _kNetworkIpKey = 'receipt_networkIp';
const _kNetworkPortKey = 'receipt_networkPort';
const _kAutoCutKey = 'receipt_autoCut';
const _kOpenCashDrawerKey = 'receipt_openCashDrawer';
const _kShowDrugLicenseKey = 'receipt_showDrugLicense';
const _kShowSavingsBannerKey = 'receipt_showSavingsBanner';
const _kShowUpiQrKey = 'receipt_showUpiQr';

enum PrinterConnectionType { network, bluetooth, system }

class ReceiptPrintSettings {
  final String paperSize; // '58mm' or '80mm'
  final PrinterConnectionType connectionType;
  final String networkIp;
  final int networkPort;
  final bool autoCut;
  final bool openCashDrawer;
  final bool showStoreAddress;
  final bool showGstin;
  final bool showDrugLicense;
  final bool showHsnCode;
  final bool showTaxBreakdown;
  final bool showSavingsBanner;
  final bool showUpiQr;
  final String footerText;

  const ReceiptPrintSettings({
    this.paperSize = '58mm',
    this.connectionType = PrinterConnectionType.network,
    this.networkIp = '192.168.1.200',
    this.networkPort = 9100,
    this.autoCut = true,
    this.openCashDrawer = false,
    this.showStoreAddress = true,
    this.showGstin = true,
    this.showDrugLicense = true,
    this.showHsnCode = false,
    this.showTaxBreakdown = true,
    this.showSavingsBanner = true,
    this.showUpiQr = true,
    this.footerText = 'Thank you for your business!',
  });

  ReceiptPrintSettings copyWith({
    String? paperSize,
    PrinterConnectionType? connectionType,
    String? networkIp,
    int? networkPort,
    bool? autoCut,
    bool? openCashDrawer,
    bool? showStoreAddress,
    bool? showGstin,
    bool? showDrugLicense,
    bool? showHsnCode,
    bool? showTaxBreakdown,
    bool? showSavingsBanner,
    bool? showUpiQr,
    String? footerText,
  }) {
    return ReceiptPrintSettings(
      paperSize: paperSize ?? this.paperSize,
      connectionType: connectionType ?? this.connectionType,
      networkIp: networkIp ?? this.networkIp,
      networkPort: networkPort ?? this.networkPort,
      autoCut: autoCut ?? this.autoCut,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      showStoreAddress: showStoreAddress ?? this.showStoreAddress,
      showGstin: showGstin ?? this.showGstin,
      showDrugLicense: showDrugLicense ?? this.showDrugLicense,
      showHsnCode: showHsnCode ?? this.showHsnCode,
      showTaxBreakdown: showTaxBreakdown ?? this.showTaxBreakdown,
      showSavingsBanner: showSavingsBanner ?? this.showSavingsBanner,
      showUpiQr: showUpiQr ?? this.showUpiQr,
      footerText: footerText ?? this.footerText,
    );
  }
}

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

  Future<ReceiptPrintSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final connTypeStr = prefs.getString(_kConnectionTypeKey) ?? 'network';
    final connType = switch (connTypeStr) {
      'bluetooth' => PrinterConnectionType.bluetooth,
      'system' => PrinterConnectionType.system,
      _ => PrinterConnectionType.network,
    };

    return ReceiptPrintSettings(
      paperSize: prefs.getString('receipt_paperSize') ?? '58mm',
      connectionType: connType,
      networkIp: prefs.getString(_kNetworkIpKey) ?? '192.168.1.200',
      networkPort: prefs.getInt(_kNetworkPortKey) ?? 9100,
      autoCut: prefs.getBool(_kAutoCutKey) ?? true,
      openCashDrawer: prefs.getBool(_kOpenCashDrawerKey) ?? false,
      showStoreAddress: prefs.getBool('receipt_showStoreAddress') ?? true,
      showGstin: prefs.getBool('receipt_showGstin') ?? true,
      showDrugLicense: prefs.getBool(_kShowDrugLicenseKey) ?? true,
      showHsnCode: prefs.getBool('receipt_showHsnCode') ?? false,
      showTaxBreakdown: prefs.getBool('receipt_showTaxBreakdown') ?? true,
      showSavingsBanner: prefs.getBool(_kShowSavingsBannerKey) ?? true,
      showUpiQr: prefs.getBool(_kShowUpiQrKey) ?? true,
      footerText: prefs.getString('receipt_footerText') ?? 'Thank you for your business!',
    );
  }

  Future<void> saveSettings(ReceiptPrintSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('receipt_paperSize', settings.paperSize);
    await prefs.setString(_kConnectionTypeKey, settings.connectionType.name);
    await prefs.setString(_kNetworkIpKey, settings.networkIp);
    await prefs.setInt(_kNetworkPortKey, settings.networkPort);
    await prefs.setBool(_kAutoCutKey, settings.autoCut);
    await prefs.setBool(_kOpenCashDrawerKey, settings.openCashDrawer);
    await prefs.setBool('receipt_showStoreAddress', settings.showStoreAddress);
    await prefs.setBool('receipt_showGstin', settings.showGstin);
    await prefs.setBool(_kShowDrugLicenseKey, settings.showDrugLicense);
    await prefs.setBool('receipt_showHsnCode', settings.showHsnCode);
    await prefs.setBool('receipt_showTaxBreakdown', settings.showTaxBreakdown);
    await prefs.setBool(_kShowSavingsBannerKey, settings.showSavingsBanner);
    await prefs.setBool(_kShowUpiQrKey, settings.showUpiQr);
    await prefs.setString('receipt_footerText', settings.footerText);
  }

  // --- Bluetooth Connection Management ---

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

  // --- ESC/POS Raw Byte Transmission ---

  /// Direct raw socket transmission over TCP/IP LAN/WiFi to thermal printer (port 9100 default).
  Future<void> printOverNetwork({
    required String ip,
    int port = 9100,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: timeout);
      socket.add(bytes);
      await socket.flush();
      await socket.close();
    } catch (e) {
      debugPrint('[ThermalPrint] Raw socket failed to $ip:$port : $e');
      rethrow;
    } finally {
      socket?.destroy();
    }
  }

  /// Write raw bytes to Bluetooth LE characteristic.
  Future<void> printBluetoothBytes(List<int> bytes) async {
    if (_writeChar == null) throw Exception('No Bluetooth printer connected');

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

  /// Print complete receipt using configured printer connection type.
  Future<void> printReceipt({
    required Map<String, dynamic> receipt,
    required Map<String, dynamic> org,
    ReceiptPrintSettings? settings,
    String? upiUri,
  }) async {
    final effectiveSettings = settings ?? await loadSettings();
    final bytes = await buildReceiptBytes(
      receipt: receipt,
      org: org,
      settings: effectiveSettings,
      upiUri: upiUri,
    );

    switch (effectiveSettings.connectionType) {
      case PrinterConnectionType.network:
        await printOverNetwork(
          ip: effectiveSettings.networkIp,
          port: effectiveSettings.networkPort,
          bytes: bytes,
        );
        break;
      case PrinterConnectionType.bluetooth:
        if (!isConnected) {
          final ok = await reconnectSaved();
          if (!ok) throw Exception('Bluetooth printer is not connected');
        }
        await printBluetoothBytes(bytes);
        break;
      case PrinterConnectionType.system:
        // System dialog fallback or no-op
        break;
    }
  }

  /// Generate raw ESC/POS byte sequence.
  Future<List<int>> buildReceiptBytes({
    required Map<String, dynamic> receipt,
    required Map<String, dynamic> org,
    required ReceiptPrintSettings settings,
    String? upiUri,
  }) async {
    final paper = settings.paperSize == '80mm' ? PaperSize.mm80 : PaperSize.mm58;
    final profile = await CapabilityProfile.load();
    final gen = Generator(paper, profile);
    List<int> bytes = [];

    // Hardware cash drawer pulse (if enabled)
    if (settings.openCashDrawer) {
      // ESC p m t1 t2 (Kick drawer 1: 0x1B, 0x70, 0x00, 0x19, 0xFA)
      bytes += [0x1B, 0x70, 0x00, 0x19, 0xFA];
    }

    bytes += gen.reset();

    // Store name (Bold, Double height)
    final orgName = org['name']?.toString() ?? 'KATASTICHO POS';
    if (orgName.isNotEmpty) {
      bytes += gen.text(
        orgName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      );
      bytes += gen.emptyLines(1);
    }

    // Store address & Phone
    if (settings.showStoreAddress) {
      final addr = org['address']?.toString() ?? '';
      if (addr.isNotEmpty) {
        bytes += gen.text(addr, styles: const PosStyles(align: PosAlign.center));
      }
      final phone = (org['phone'] ?? org['contactPhone'])?.toString() ?? '';
      if (phone.isNotEmpty) {
        bytes += gen.text('Ph: $phone', styles: const PosStyles(align: PosAlign.center));
      }
    }

    // GSTIN
    if (settings.showGstin) {
      final gstin = (org['gstin'] ?? org['taxNumber'])?.toString() ?? '';
      if (gstin.isNotEmpty) {
        bytes += gen.text('GSTIN: $gstin', styles: const PosStyles(align: PosAlign.center));
      }
    }

    // Pharma Drug License (DL Number)
    if (settings.showDrugLicense) {
      final dlNo = (org['drugLicenseNo'] ?? org['drugLicense'] ?? org['dlNumber'])?.toString() ?? '';
      if (dlNo.isNotEmpty) {
        bytes += gen.text('D.L. No: $dlNo', styles: const PosStyles(align: PosAlign.center));
      }
    }

    bytes += gen.hr();

    // Bill Number & Date
    final receiptNumber = receipt['receiptNumber']?.toString() ?? 'REC-TEMP';
    final receiptDate = receipt['receiptDate']?.toString() ?? DateTime.now().toIso8601String();
    final cashier = (receipt['cashierName'] ?? receipt['createdByName'])?.toString() ?? '';

    bytes += gen.text('Bill No: $receiptNumber', styles: const PosStyles(bold: true));
    bytes += gen.text('Date: ${_formatDate(receiptDate)}   Time: ${_formatTime(receiptDate)}');
    if (cashier.isNotEmpty) {
      bytes += gen.text('Cashier: $cashier');
    }

    // Customer Name & Mobile
    final contactName = receipt['contactName']?.toString() ?? '';
    final contactPhone = receipt['contactPhone']?.toString() ?? '';
    if (contactName.isNotEmpty && contactName != 'Walk-in Customer') {
      bytes += gen.text('Customer: $contactName${contactPhone.isNotEmpty ? " ($contactPhone)" : ""}');
    }

    bytes += gen.hr(ch: '-');

    // Column Headers
    if (paper == PaperSize.mm80) {
      bytes += gen.row([
        PosColumn(text: 'Item / Batch', width: 6, styles: const PosStyles(bold: true)),
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

    // Line Items
    final lines = (receipt['lines'] as List<dynamic>?) ?? [];
    double totalDiscount = 0.0;

    for (final line in lines) {
      final name = (line['itemName'] ?? line['description'] ?? 'Item').toString();
      final qty = _num(line['quantity']);
      final rate = _num(line['rate'] ?? line['unitPrice']);
      final amount = _num(line['amount'] ?? line['totalAmount']);
      final unit = (line['unit'] ?? 'PCS').toString().toUpperCase();
      final batchNo = line['batchNumber']?.toString() ?? '';
      final expiry = line['expiryDate']?.toString() ?? '';
      final lineDisc = _num(line['discountAmount']);
      totalDiscount += lineDisc;

      if (paper == PaperSize.mm80) {
        final displayName = name.length > 22 ? name.substring(0, 22) : name;
        bytes += gen.row([
          PosColumn(text: displayName, width: 6),
          PosColumn(text: '${_fmtQty(qty)} $unit', width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: _fmtAmt(rate), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: _fmtAmt(amount), width: 2, styles: const PosStyles(align: PosAlign.right)),
        ]);
        if (batchNo.isNotEmpty || expiry.isNotEmpty) {
          final pharmaMeta = [
            if (batchNo.isNotEmpty) 'B: $batchNo',
            if (expiry.isNotEmpty) 'Exp: ${_formatExpiry(expiry)}',
          ].join('  ');
          bytes += gen.text('  $pharmaMeta', styles: const PosStyles(fontType: PosFontType.fontB));
        }
      } else {
        if (name.length > 16) {
          bytes += gen.text(name);
          bytes += gen.row([
            PosColumn(text: batchNo.isNotEmpty ? 'B:$batchNo' : '', width: 7, styles: const PosStyles(fontType: PosFontType.fontB)),
            PosColumn(text: '${_fmtQty(qty)} $unit', width: 2, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: _fmtAmt(amount), width: 3, styles: const PosStyles(align: PosAlign.right)),
          ]);
        } else {
          bytes += gen.row([
            PosColumn(text: name, width: 7),
            PosColumn(text: '${_fmtQty(qty)} $unit', width: 2, styles: const PosStyles(align: PosAlign.right)),
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

    // Totals & Taxes
    final subtotal = _num(receipt['subtotal'] ?? receipt['taxableAmount']);
    final cgst = _num(receipt['cgst']);
    final sgst = _num(receipt['sgst']);
    final igst = _num(receipt['igst']);
    final total = _num(receipt['total'] ?? receipt['totalAmount'] ?? receipt['netPayable']);
    final receiptDiscount = _num(receipt['discountTotal'] ?? receipt['discountAmount']);
    final finalSavings = receiptDiscount > 0 ? receiptDiscount : totalDiscount;

    bytes += _totalRow(gen, 'Subtotal', subtotal);

    if (finalSavings > 0) {
      bytes += _totalRow(gen, 'Trade Discount', -finalSavings);
    }

    if (settings.showTaxBreakdown) {
      if (cgst > 0) bytes += _totalRow(gen, 'CGST', cgst);
      if (sgst > 0) bytes += _totalRow(gen, 'SGST', sgst);
      if (igst > 0) bytes += _totalRow(gen, 'IGST', igst);
    }

    final roundOff = _num(receipt['roundOff'] ?? receipt['roundingAdjustment']);
    if (roundOff != 0) {
      bytes += _totalRow(gen, 'Round Off', roundOff);
    }

    bytes += gen.hr(ch: '=');

    // Grand Total (Double Height)
    bytes += gen.row([
      PosColumn(text: 'TOTAL DUE', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: 'INR ${_fmtAmt(total)}',
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]);

    // Payment info
    final paymentMode = (receipt['paymentMode'] ?? 'CASH').toString().toUpperCase();
    final amountReceived = _num(receipt['amountReceived']);
    final changeReturned = _num(receipt['changeReturned']);

    bytes += gen.emptyLines(1);
    bytes += gen.text('Paid via: $paymentMode (${_fmtAmt(amountReceived > 0 ? amountReceived : total)})',
        styles: const PosStyles(align: PosAlign.center));
    if (changeReturned > 0) {
      bytes += gen.text('Change Returned: INR ${_fmtAmt(changeReturned)}',
          styles: const PosStyles(align: PosAlign.center, bold: true));
    }

    // Savings Banner
    if (settings.showSavingsBanner && finalSavings > 0) {
      bytes += gen.emptyLines(1);
      bytes += gen.text(
        '*** YOU SAVED INR ${_fmtAmt(finalSavings)} ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    // Dynamic UPI QR Code
    if (settings.showUpiQr && upiUri != null && upiUri.isNotEmpty) {
      bytes += gen.emptyLines(1);
      bytes += gen.text('Scan with UPI to Verify / Pay', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += gen.qrcode(upiUri, size: QRSize.size4);
    }

    bytes += gen.hr();

    // Footer
    if (settings.footerText.isNotEmpty) {
      bytes += gen.text(settings.footerText, styles: const PosStyles(align: PosAlign.center));
    }
    bytes += gen.text('Powered by Katasticho ERP',
        styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB));

    // Hardware Cut
    if (settings.autoCut) {
      bytes += gen.emptyLines(2);
      bytes += gen.cut();
    }

    return bytes;
  }

  /// Send a test print slip over Network Socket or Bluetooth.
  Future<void> testPrint({
    required ReceiptPrintSettings settings,
    required Map<String, dynamic> org,
  }) async {
    final dummyReceipt = {
      'receiptNumber': 'TEST-${DateTime.now().millisecondsSinceEpoch % 10000}',
      'receiptDate': DateTime.now().toIso8601String(),
      'cashierName': 'Admin',
      'contactName': 'Cash Counter Test',
      'lines': [
        {
          'itemName': 'Paracetamol 500mg (10s)',
          'quantity': 2,
          'unit': 'STRIP',
          'rate': 20.0,
          'amount': 40.0,
          'batchNumber': 'BATCH-99',
          'expiryDate': '2027-12-31',
          'hsnCode': '30049099',
        },
        {
          'itemName': 'Amoxicillin 250mg Dry Syrup',
          'quantity': 1,
          'unit': 'BTL',
          'rate': 55.0,
          'amount': 55.0,
          'batchNumber': 'AMX-02',
          'expiryDate': '2026-09-30',
          'hsnCode': '30041010',
        },
      ],
      'subtotal': 95.0,
      'discountTotal': 5.0,
      'cgst': 2.25,
      'sgst': 2.25,
      'igst': 0.0,
      'roundOff': 0.50,
      'total': 95.0,
      'paymentMode': 'CASH',
      'amountReceived': 100.0,
      'changeReturned': 5.0,
    };

    await printReceipt(
      receipt: dummyReceipt,
      org: org,
      settings: settings,
      upiUri: 'upi://pay?pa=test@upi&pn=KatastichoTest&am=95.00&cu=INR',
    );
  }

  List<int> _totalRow(Generator gen, String label, double amount) {
    return gen.row([
      PosColumn(text: label, width: 6),
      PosColumn(
        text: _fmtAmt(amount.abs()),
        width: 6,
        styles: PosStyles(align: PosAlign.right, bold: label == 'TOTAL DUE'),
      ),
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

  static String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final hour = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$hour:$min';
    } catch (_) {
      return '';
    }
  }

  static String _formatExpiry(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month.toString().padLeft(2, '0')}/${dt.year.toString().substring(2)}';
    } catch (_) {
      return iso;
    }
  }
}
