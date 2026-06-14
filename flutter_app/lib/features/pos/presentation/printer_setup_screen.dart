import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../data/thermal_print_service.dart';

class PrinterSetupScreen extends StatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  State<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends State<PrinterSetupScreen> {
  final _printService = ThermalPrintService.instance;
  List<ScanResult> _devices = [];
  bool _scanning = false;
  String? _connectingId;
  String? _savedName;
  bool _autoPrint = false;

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final name = await _printService.savedPrinterName;
    final auto = await _printService.autoPrintEnabled;
    if (mounted) setState(() { _savedName = name; _autoPrint = auto; });
  }

  Future<void> _startScan() async {
    setState(() { _scanning = true; _devices = []; });
    try {
      final results = await _printService.scanForPrinters();
      if (mounted) setState(() => _devices = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    setState(() => _connectingId = device.remoteId.str);
    try {
      final ok = await _printService.connectToDevice(device);
      if (mounted) {
        if (ok) {
          setState(() => _savedName = device.platformName.isNotEmpty
              ? device.platformName : device.remoteId.str);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Printer connected')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not find writable characteristic')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  Future<void> _testPrint() async {
    if (!_printService.isConnected) {
      final ok = await _printService.reconnectSaved();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Printer not connected')));
        }
        return;
      }
    }

    try {
      await _printService.printReceipt(
        receipt: {
          'receiptNumber': 'TEST-001',
          'receiptDate': DateTime.now().toIso8601String(),
          'lines': [
            {'itemName': 'Test Item 1', 'quantity': 2, 'rate': 50, 'amount': 100, 'unit': 'PCS'},
            {'itemName': 'Test Item 2', 'quantity': 1, 'rate': 75, 'amount': 75, 'unit': 'PCS'},
          ],
          'subtotal': 175,
          'cgst': 0,
          'sgst': 0,
          'igst': 0,
          'total': 175,
          'paymentMode': 'CASH',
          'amountReceived': 200,
          'changeReturned': 25,
        },
        org: {'name': 'Test Store', 'address': '123 Test St', 'phone': '9876543210'},
        settings: const ReceiptPrintSettings(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test print sent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCurrentPrinter(),
          KSpacing.vGapLg,
          _buildAutoPrint(),
          KSpacing.vGapLg,
          _buildScanSection(),
        ],
      ),
    );
  }

  Widget _buildCurrentPrinter() {
    final connected = _printService.isConnected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Printer', style: KTypography.h3),
            KSpacing.vGapSm,
            Row(
              children: [
                Icon(
                  connected ? Icons.print : Icons.print_disabled,
                  color: connected ? KColors.success : KColors.textSecondary,
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _savedName ?? 'No printer selected',
                        style: KTypography.labelLarge,
                      ),
                      Text(
                        connected ? 'Connected' : (_savedName != null ? 'Saved (tap to reconnect)' : 'Scan below to pair'),
                        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_savedName != null) ...[
                  if (!connected)
                    TextButton(
                      onPressed: () async {
                        final ok = await _printService.reconnectSaved();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok ? 'Reconnected' : 'Could not reconnect'),
                          ));
                          setState(() {});
                        }
                      },
                      child: const Text('Connect'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: KColors.error),
                    onPressed: () async {
                      await _printService.clearSavedPrinter();
                      if (mounted) setState(() => _savedName = null);
                    },
                  ),
                ],
              ],
            ),
            if (connected) ...[
              KSpacing.vGapMd,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _testPrint,
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Test Print'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutoPrint() {
    return Card(
      child: SwitchListTile(
        title: const Text('Auto-print on sale'),
        subtitle: const Text('Automatically print receipt after each sale'),
        value: _autoPrint,
        onChanged: (v) {
          setState(() => _autoPrint = v);
          _printService.setAutoPrint(v);
        },
      ),
    );
  }

  Widget _buildScanSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Available Devices', style: KTypography.h3),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _scanning ? null : _startScan,
                  icon: _scanning
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.bluetooth_searching, size: 18),
                  label: Text(_scanning ? 'Scanning...' : 'Scan'),
                ),
              ],
            ),
            KSpacing.vGapMd,
            if (_devices.isEmpty && !_scanning)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(Icons.bluetooth, size: 48, color: KColors.textSecondary.withValues(alpha: 0.5)),
                      KSpacing.vGapSm,
                      Text('Tap Scan to find nearby printers',
                          style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ..._devices.map((r) => _buildDeviceTile(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceTile(ScanResult result) {
    final device = result.device;
    final name = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;
    final isConnecting = _connectingId == device.remoteId.str;
    final isThisConnected = _printService.isConnected &&
        _printService.connectedPrinterName == device.platformName;

    return ListTile(
      leading: Icon(
        Icons.print,
        color: isThisConnected ? KColors.success : KColors.primary,
      ),
      title: Text(name),
      subtitle: Text('RSSI: ${result.rssi} dBm'),
      trailing: isConnecting
          ? const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : isThisConnected
              ? const Icon(Icons.check_circle, color: KColors.success)
              : const Icon(Icons.link, color: KColors.primary),
      onTap: isConnecting ? null : () => _connectTo(device),
    );
  }
}
