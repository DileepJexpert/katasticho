import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';

/// Opens a barcode scanner overlay. Returns the scanned barcode string or null.
Future<String?> showBarcodeScanner(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    builder: (_) => const _BarcodeScannerContent(),
  );
}

class _BarcodeScannerContent extends StatefulWidget {
  const _BarcodeScannerContent();

  @override
  State<_BarcodeScannerContent> createState() => _BarcodeScannerContentState();
}

class _BarcodeScannerContentState extends State<_BarcodeScannerContent> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _scanned = true);
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height * 0.6,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            color: Colors.black,
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner,
                    color: Colors.white, size: 20),
                KSpacing.hGapSm,
                Text('Scan Barcode',
                    style: KTypography.labelLarge
                        .copyWith(color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (_, state, __) {
                      final torchOn = state.torchState == TorchState.on;
                      return Icon(
                        torchOn ? Icons.flash_on : Icons.flash_off,
                        color: torchOn ? KColors.warning : Colors.white,
                      );
                    },
                  ),
                  onPressed: () => _controller.toggleTorch(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Scanner
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                // Scan area overlay
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: KColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          // Hint
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black,
            child: Text(
              'Point camera at barcode or QR code',
              style: KTypography.bodySmall.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
