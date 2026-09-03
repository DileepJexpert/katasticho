import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/barcode_label_repository.dart';

class BarcodeLabelDesignerScreen extends ConsumerStatefulWidget {
  const BarcodeLabelDesignerScreen({super.key});

  @override
  ConsumerState<BarcodeLabelDesignerScreen> createState() => _BarcodeLabelDesignerScreenState();
}

class _BarcodeLabelDesignerScreenState extends ConsumerState<BarcodeLabelDesignerScreen> {
  final _formKey = GlobalKey<FormState>();

  int _widthMm = 50;
  int _heightMm = 25;
  int _dpi = 203;
  String _barcodeType = 'CODE128'; // CODE128, EAN13, QR

  final _itemNameController = TextEditingController(text: 'Augmentin 625mg Duo Strip');
  final _skuController = TextEditingController(text: 'MED-AUG-625');
  final _barcodeController = TextEditingController(text: '8901234567890');
  final _batchController = TextEditingController(text: 'B2026-X8');
  final _expiryController = TextEditingController(text: '12/2028');
  final _mrpController = TextEditingController(text: '204.50');
  final _sellingPriceController = TextEditingController(text: '180.00');
  final _fssaiController = TextEditingController(text: '10020011000123');
  final _companyController = TextEditingController(text: 'KATASTICHO HEALTHCARE');
  final _copiesController = TextEditingController(text: '1');

  BarcodeLabelGenerateResponseDto? _generatedResponse;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _generateZpl();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    _mrpController.dispose();
    _sellingPriceController.dispose();
    _fssaiController.dispose();
    _companyController.dispose();
    _copiesController.dispose();
    super.dispose();
  }

  Future<void> _generateZpl() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isGenerating = true);

    try {
      final repo = ref.read(barcodeLabelRepositoryProvider);
      final req = BarcodeLabelGenerateRequestDto(
        itemName: _itemNameController.text.trim(),
        sku: _skuController.text.trim().isNotEmpty ? _skuController.text.trim() : null,
        barcodeValue: _barcodeController.text.trim(),
        barcodeType: _barcodeType,
        batchNumber: _batchController.text.trim().isNotEmpty ? _batchController.text.trim() : null,
        expiryDate: _expiryController.text.trim().isNotEmpty ? _expiryController.text.trim() : null,
        mrp: double.tryParse(_mrpController.text.replaceAll(',', '')),
        sellingPrice: double.tryParse(_sellingPriceController.text.replaceAll(',', '')),
        fssaiLicNo: _fssaiController.text.trim().isNotEmpty ? _fssaiController.text.trim() : null,
        companyName: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
        labelWidthMm: _widthMm,
        labelHeightMm: _heightMm,
        dpi: _dpi,
        copies: int.tryParse(_copiesController.text) ?? 1,
      );

      final res = await repo.generateLabel(req);
      if (mounted) setState(() => _generatedResponse = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate ZPL: $e'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _copyZpl() {
    if (_generatedResponse == null) return;
    Clipboard.setData(ClipboardData(text: _generatedResponse!.zplCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ZPL II command code copied to clipboard!'), backgroundColor: KColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Industrial Barcode Label Designer'),
        actions: [
          KButton.secondary(
            label: 'Copy ZPL Code',
            icon: Icons.copy,
            onPressed: _generatedResponse != null ? _copyZpl : null,
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: _isGenerating ? 'Generating…' : 'Generate ZPL',
            icon: Icons.refresh,
            onPressed: _isGenerating ? null : _generateZpl,
          ),
          KSpacing.hGapSm,
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Configuration Form
              Expanded(
                flex: isWide ? 5 : 12,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: KSpacing.pagePadding,
                    children: [
                      // Dimension Preset Cards
                      Text('Label Dimensions', style: KTypography.labelLarge),
                      KSpacing.vGapSm,
                      _buildDimensionPresets(),
                      KSpacing.vGapLg,

                      // Barcode Format & DPI
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              initialValue: _barcodeType,
                              decoration: const InputDecoration(
                                labelText: 'Symbology',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'CODE128', child: Text('Code 128 (Standard)')),
                                DropdownMenuItem(value: 'EAN13', child: Text('EAN-13 (Retail GS1)')),
                                DropdownMenuItem(value: 'QR', child: Text('2D QR Code')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _barcodeType = val);
                                  _generateZpl();
                                }
                              },
                            ),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              initialValue: _dpi,
                              decoration: const InputDecoration(
                                labelText: 'Resolution',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 203, child: Text('203 DPI (8 d/mm)')),
                                DropdownMenuItem(value: 300, child: Text('300 DPI (12 d/mm)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _dpi = val);
                                  _generateZpl();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      KSpacing.vGapLg,

                      // Item & Barcode Data
                      Text('Item & Batch Attributes', style: KTypography.labelLarge),
                      KSpacing.vGapSm,
                      KCard(
                        child: Column(
                          children: [
                            KTextField(
                              controller: _itemNameController,
                              label: 'Product / Item Title',
                              onChanged: (_) => _generateZpl(),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            KSpacing.vGapMd,
                            Row(
                              children: [
                                Expanded(
                                  child: KTextField(
                                    controller: _barcodeController,
                                    label: 'Barcode Value',
                                    onChanged: (_) => _generateZpl(),
                                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                KSpacing.hGapMd,
                                Expanded(
                                  child: KTextField(
                                    controller: _skuController,
                                    label: 'SKU / Item Code',
                                    onChanged: (_) => _generateZpl(),
                                  ),
                                ),
                              ],
                            ),
                            KSpacing.vGapMd,
                            Row(
                              children: [
                                Expanded(
                                  child: KTextField(
                                    controller: _batchController,
                                    label: 'Batch No',
                                    hint: 'e.g. B-9981',
                                    onChanged: (_) => _generateZpl(),
                                  ),
                                ),
                                KSpacing.hGapMd,
                                Expanded(
                                  child: KTextField(
                                    controller: _expiryController,
                                    label: 'Expiry (MM/YYYY)',
                                    hint: '12/2028',
                                    onChanged: (_) => _generateZpl(),
                                  ),
                                ),
                              ],
                            ),
                            KSpacing.vGapMd,
                            Row(
                              children: [
                                Expanded(
                                  child: KTextField.amount(
                                    controller: _mrpController,
                                    label: 'MRP (₹)',
                                    hint: '0.00',
                                    onChanged: (_) => _generateZpl(),
                                  ),
                                ),
                                KSpacing.hGapMd,
                                Expanded(
                                  child: KTextField.amount(
                                    controller: _sellingPriceController,
                                    label: 'Our Price (₹)',
                                    hint: '0.00',
                                    onChanged: (_) => _generateZpl(),
                                  ),
                                ),
                              ],
                            ),
                            KSpacing.vGapMd,
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: KTextField(
                                    controller: _companyController,
                                    label: 'Company Header',
                                    onChanged: (_) => _generateZpl(),
                                  ),
                                ),
                                KSpacing.hGapMd,
                                Expanded(
                                  flex: 2,
                                  child: KTextField(
                                    controller: _fssaiController,
                                    label: 'FSSAI / Lic No',
                                    onChanged: (_) => _generateZpl(),
                                  ),
                                ),
                              ],
                            ),
                            KSpacing.vGapMd,
                            KTextField(
                              controller: _copiesController,
                              label: 'Print Copies',
                              hint: '1',
                              onChanged: (_) => _generateZpl(),
                            ),
                          ],
                        ),
                      ),
                      KSpacing.vGapXl,
                    ],
                  ),
                ),
              ),

              // Right: Live Visual Sticker Preview & Raw ZPL
              if (isWide) ...[
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 7,
                  child: Container(
                    color: const Color(0xFFE5E7EB),
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text('Live Sticker Preview (${_widthMm}mm × ${_heightMm}mm @ $_dpi DPI)',
                              style: KTypography.labelLarge.copyWith(color: KColors.textSecondary)),
                          KSpacing.vGapMd,
                          _buildLiveStickerPreview(),
                          KSpacing.vGapXl,

                          // Raw ZPL code block
                          if (_generatedResponse != null) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Zebra ZPL II Raw Command Stream', style: KTypography.labelMedium),
                                  TextButton.icon(
                                    icon: const Icon(Icons.copy, size: 16),
                                    label: const Text('Copy ZPL'),
                                    onPressed: _copyZpl,
                                  ),
                                ],
                              ),
                            ),
                            KSpacing.vGapXs,
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SelectableText(
                                _generatedResponse!.zplCode,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDimensionPresets() {
    final presets = [
      {'w': 50, 'h': 25, 'title': '50 × 25 mm', 'sub': 'Retail / Pharma Item Sticker'},
      {'w': 100, 'h': 50, 'title': '100 × 50 mm', 'sub': 'Inner Box / Shipping Carton'},
      {'w': 100, 'h': 150, 'title': '100 × 150 mm', 'sub': 'Master Pallet / Case Tag'},
    ];

    return Row(
      children: presets.map((p) {
        final isSel = _widthMm == p['w'] && _heightMm == p['h'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _widthMm = p['w'] as int;
                  _heightMm = p['h'] as int;
                });
                _generateZpl();
              },
              borderRadius: KSpacing.borderRadiusMd,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSel ? KColors.primary.withValues(alpha: 0.1) : KColors.surface,
                  border: Border.all(color: isSel ? KColors.primary : KColors.border, width: isSel ? 2 : 1),
                  borderRadius: KSpacing.borderRadiusMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['title'] as String, style: KTypography.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                    KSpacing.vGapXs,
                    Text(p['sub'] as String, style: KTypography.bodySmall.copyWith(color: KColors.textHint, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiveStickerPreview() {
    final double displayWidth = (_widthMm * 6.5).clamp(320.0, 480.0);
    final double aspectRatio = _widthMm / _heightMm;

    return Container(
      width: displayWidth,
      height: displayWidth / aspectRatio,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black26),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header Company
          if (_companyController.text.trim().isNotEmpty)
            Text(
              _companyController.text.trim().toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),

          // Title
          Text(
            _itemNameController.text.trim(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // Barcode Simulation
          Center(
            child: _barcodeType == 'QR'
                ? Container(
                    width: 55,
                    height: 55,
                    color: Colors.black,
                    child: const Icon(Icons.qr_code_2, color: Colors.white, size: 50),
                  )
                : Column(
                    children: [
                      Container(
                        height: 38,
                        width: displayWidth * 0.75,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage('https://placeholder.com/barcode'),
                            fit: BoxFit.fill,
                          ),
                        ),
                        child: _BarcodeBarsSimulation(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _barcodeController.text.trim(),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),

          // Metadata Details (Batch, Exp, Price)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_batchController.text.trim().isNotEmpty)
                    Text('B.No: ${_batchController.text.trim()}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  if (_expiryController.text.trim().isNotEmpty)
                    Text('Exp: ${_expiryController.text.trim()}', style: const TextStyle(fontSize: 9, color: Colors.black87)),
                  if (_fssaiController.text.trim().isNotEmpty)
                    Text('FSSAI: ${_fssaiController.text.trim()}', style: const TextStyle(fontSize: 8, color: Colors.black54)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_mrpController.text.trim().isNotEmpty)
                    Text('MRP: ₹ ${_mrpController.text.trim()}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  if (_sellingPriceController.text.trim().isNotEmpty)
                    Text('Our Price: ₹ ${_sellingPriceController.text.trim()}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: KColors.primary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarcodeBarsSimulation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(42, (index) {
        final isThick = index % 3 == 0 || index % 7 == 0;
        final isSpace = index % 5 == 0;
        return Container(
          width: isThick ? 3.0 : 1.5,
          color: isSpace ? Colors.transparent : Colors.black,
          margin: const EdgeInsets.symmetric(horizontal: 0.8),
        );
      }),
    );
  }
}