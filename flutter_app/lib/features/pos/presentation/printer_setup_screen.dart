import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/thermal_print_service.dart';

class PrinterSetupScreen extends ConsumerStatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  ConsumerState<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends ConsumerState<PrinterSetupScreen> {
  final _printService = ThermalPrintService.instance;
  ReceiptPrintSettings _settings = const ReceiptPrintSettings();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();

  List<ScanResult> _devices = [];
  bool _scanning = false;
  String? _connectingId;
  String? _savedBluetoothName;
  bool _autoPrint = false;
  bool _testingPrint = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final settings = await _printService.loadSettings();
    final auto = await _printService.autoPrintEnabled;
    final btName = await _printService.savedPrinterName;

    if (mounted) {
      setState(() {
        _settings = settings;
        _autoPrint = auto;
        _savedBluetoothName = btName;
        _ipController.text = settings.networkIp;
        _portController.text = settings.networkPort.toString();
      });
    }
  }

  Future<void> _saveSettings(ReceiptPrintSettings updated) async {
    setState(() => _settings = updated);
    await _printService.saveSettings(updated);
  }

  Future<void> _startBluetoothScan() async {
    setState(() {
      _scanning = true;
      _devices = [];
    });
    try {
      final results = await _printService.scanForPrinters();
      if (mounted) setState(() => _devices = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connectBluetoothDevice(BluetoothDevice device) async {
    setState(() => _connectingId = device.remoteId.str);
    try {
      final ok = await _printService.connectToDevice(device);
      if (mounted) {
        if (ok) {
          final name = device.platformName.isNotEmpty ? device.platformName : device.remoteId.str;
          setState(() => _savedBluetoothName = name);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bluetooth printer connected: $name')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find writable printer characteristic'),
              backgroundColor: KColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  Future<void> _testPrint() async {
    setState(() => _testingPrint = true);
    try {
      final auth = ref.read(authProvider);
      final orgName = auth.orgName ?? 'Katasticho Demo Store';

      await _printService.testPrint(
        settings: _settings,
        org: {
          'name': orgName,
          'address': 'Main Market Road, Sector 12',
          'phone': '9876543210',
          'gstin': '07AAAAA0000A1Z5',
          'drugLicenseNo': 'DL-20B-12345/21B-67890',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingPrint = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thermal Printer Setup')),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          // Connection Mode Selector
          Text('Printer Connection Interface', style: KTypography.h3),
          KSpacing.vGapXs,
          Text(
            'High-speed zero-dialog direct ESC/POS printing over Network (TCP/IP) or Bluetooth.',
            style: KTypography.caption.copyWith(color: KColors.textSecondary),
          ),
          KSpacing.vGapSm,
          KCard(
            child: RadioGroup<PrinterConnectionType>(
              groupValue: _settings.connectionType,
              onChanged: (val) {
                if (val != null) _saveSettings(_settings.copyWith(connectionType: val));
              },
              child: Column(
                children: const [
                  RadioListTile<PrinterConnectionType>(
                    value: PrinterConnectionType.network,
                    title: Text('Direct Network / Ethernet (Raw TCP Socket)'),
                    subtitle: Text('Recommended for LAN/WiFi thermal printers (Epson, TVS, NGX, Everycom) — Port 9100'),
                  ),
                  Divider(height: 1),
                  RadioListTile<PrinterConnectionType>(
                    value: PrinterConnectionType.bluetooth,
                    title: Text('Direct Bluetooth (BLE / Wireless)'),
                    subtitle: Text('For portable hand-held 58mm / 80mm Bluetooth billing machines'),
                  ),
                  Divider(height: 1),
                  RadioListTile<PrinterConnectionType>(
                    value: PrinterConnectionType.system,
                    title: Text('System Print Dialog (Browser / OS Driver)'),
                    subtitle: Text('Standard OS print window fallback'),
                  ),
                ],
              ),
            ),
          ),
          KSpacing.vGapLg,

          // If Network: IP and Port Inputs
          if (_settings.connectionType == PrinterConnectionType.network) ...[
            Text('Network Printer Address', style: KTypography.h3),
            KSpacing.vGapSm,
            KCard(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: KTextField(
                          label: 'Printer IP Address',
                          hint: 'e.g. 192.168.1.200',
                          controller: _ipController,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            _saveSettings(_settings.copyWith(networkIp: val.trim()));
                          },
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        flex: 1,
                        child: KTextField(
                          label: 'Port',
                          hint: '9100',
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          onChanged: (val) {
                            final port = int.tryParse(val.trim()) ?? 9100;
                            _saveSettings(_settings.copyWith(networkPort: port));
                          },
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapSm,
                  Text(
                    'Default RAW port for Epson ESC/POS, Star, TVS RP series and Posiflex is 9100.',
                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                  ),
                ],
              ),
            ),
            KSpacing.vGapLg,
          ],

          // If Bluetooth: Device Scanner
          if (_settings.connectionType == PrinterConnectionType.bluetooth) ...[
            Text('Bluetooth Device Pairing', style: KTypography.h3),
            KSpacing.vGapSm,
            KCard(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _printService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                        color: _printService.isConnected ? KColors.primary : KColors.textSecondary,
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _savedBluetoothName ?? 'No Bluetooth printer paired',
                              style: KTypography.labelMedium,
                            ),
                            Text(
                              _printService.isConnected ? 'Connected & Ready' : 'Saved device',
                              style: KTypography.caption.copyWith(
                                color: _printService.isConnected ? KColors.success : KColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_savedBluetoothName != null)
                        TextButton(
                          onPressed: () async {
                            await _printService.clearSavedPrinter();
                            setState(() => _savedBluetoothName = null);
                          },
                          child: Text('Disconnect', style: TextStyle(color: KColors.error)),
                        ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  KButton(
                    label: _scanning ? 'Scanning Bluetooth Devices...' : 'Scan for Nearby Printers',
                    icon: Icons.search,
                    variant: KButtonVariant.outlined,
                    isLoading: _scanning,
                    onPressed: _scanning ? null : _startBluetoothScan,
                  ),
                  if (_devices.isNotEmpty) ...[
                    KSpacing.vGapMd,
                    const Divider(height: 1),
                    ..._devices.map((r) => ListTile(
                          dense: true,
                          title: Text(r.device.platformName, style: KTypography.labelMedium),
                          subtitle: Text(r.device.remoteId.str, style: KTypography.caption),
                          trailing: _connectingId == r.device.remoteId.str
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : FilledButton.tonal(
                                  onPressed: () => _connectBluetoothDevice(r.device),
                                  child: const Text('Pair'),
                                ),
                        )),
                  ],
                ],
              ),
            ),
            KSpacing.vGapLg,
          ],

          // Hardware & Paper Options
          Text('Paper & Hardware Controls', style: KTypography.h3),
          KSpacing.vGapSm,
          KCard(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Paper Roll Width'),
                  subtitle: Text(_settings.paperSize == '80mm' ? '80mm (3-inch wide / 48 columns)' : '58mm (2-inch standard / 32 columns)'),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '58mm', label: Text('58mm')),
                      ButtonSegment(value: '80mm', label: Text('80mm')),
                    ],
                    selected: {_settings.paperSize},
                    onSelectionChanged: (set) {
                      _saveSettings(_settings.copyWith(paperSize: set.first));
                    },
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _autoPrint,
                  title: const Text('Auto-Print on Bill Completion'),
                  subtitle: const Text('Instantly fires print without asking for confirmation'),
                  onChanged: (val) async {
                    setState(() => _autoPrint = val);
                    await _printService.setAutoPrint(val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _settings.autoCut,
                  title: const Text('Automatic Paper Cut (GS V)'),
                  subtitle: const Text('Triggers guillotine cutter at the end of every receipt'),
                  onChanged: (val) => _saveSettings(_settings.copyWith(autoCut: val)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _settings.openCashDrawer,
                  title: const Text('Kick Cash Drawer Pulse (ESC p)'),
                  subtitle: const Text('Punches 24V drawer solenoid on bill settlement'),
                  onChanged: (val) => _saveSettings(_settings.copyWith(openCashDrawer: val)),
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,

          // Slip Content Customization
          Text('Receipt Content Elements', style: KTypography.h3),
          KSpacing.vGapSm,
          KCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: _settings.showSavingsBanner,
                  title: const Text('Display "You Saved ₹X" Banner'),
                  subtitle: const Text('Highlights total scheme and bill discounts to customer'),
                  onChanged: (val) => _saveSettings(_settings.copyWith(showSavingsBanner: val)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _settings.showUpiQr,
                  title: const Text('Print Dynamic UPI QR Code'),
                  subtitle: const Text('Prints UPI QR code on slip for instant mobile scan & payment verification'),
                  onChanged: (val) => _saveSettings(_settings.copyWith(showUpiQr: val)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _settings.showDrugLicense,
                  title: const Text('Show Pharma Drug License (D.L. No)'),
                  subtitle: const Text('Mandatory statutory header for pharmacy retailers & distributors'),
                  onChanged: (val) => _saveSettings(_settings.copyWith(showDrugLicense: val)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _settings.showHsnCode,
                  title: const Text('Show HSN/SAC Code per Line'),
                  onChanged: (val) => _saveSettings(_settings.copyWith(showHsnCode: val)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _settings.showTaxBreakdown,
                  title: const Text('Show CGST + SGST Breakdown'),
                  onChanged: (val) => _saveSettings(_settings.copyWith(showTaxBreakdown: val)),
                ),
              ],
            ),
          ),
          KSpacing.vGapXl,

          // Test Print CTA
          KButton(
            label: _testingPrint ? 'Sending Test Slip...' : 'Send Test Print to Thermal Printer',
            icon: Icons.print,
            isLoading: _testingPrint,
            onPressed: _testingPrint ? null : _testPrint,
          ),
          KSpacing.vGapXl,
        ],
      ),
    );
  }
}
