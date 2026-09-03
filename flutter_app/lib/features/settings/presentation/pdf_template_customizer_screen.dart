import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/pdf_template_repository.dart';

class PdfTemplateCustomizerScreen extends ConsumerStatefulWidget {
  const PdfTemplateCustomizerScreen({super.key});

  @override
  ConsumerState<PdfTemplateCustomizerScreen> createState() => _PdfTemplateCustomizerScreenState();
}

class _PdfTemplateCustomizerScreenState extends ConsumerState<PdfTemplateCustomizerScreen> {
  String _selectedDocType = 'INVOICE'; // INVOICE, QUOTATION, BILL, DELIVERY_CHALLAN

  String _templateTheme = 'CLASSIC'; // CLASSIC, MODERN, MINIMAL, COMPACT_THERMAL
  String _primaryColor = '#0F8576';
  String _headerLayout = 'LOGO_LEFT'; // LOGO_LEFT, LOGO_RIGHT, LOGO_CENTER
  bool _showGstColumns = true;
  bool _showHsnColumn = true;
  bool _showPaymentQr = true;
  bool _showTerms = true;
  final _termsController = TextEditingController(
    text: '1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged for delayed payments.',
  );
  bool _showSignature = true;
  final _signatureLabelController = TextEditingController(text: 'Authorized Signatory');
  final _watermarkController = TextEditingController(text: 'ORIGINAL FOR RECIPIENT');

  bool _isLoading = false;
  bool _isSaving = false;

  final List<Map<String, String>> _colorPalette = [
    {'name': 'Teal', 'hex': '#0F8576'},
    {'name': 'Navy', 'hex': '#1E40AF'},
    {'name': 'Charcoal', 'hex': '#334155'},
    {'name': 'Crimson', 'hex': '#BE3A34'},
    {'name': 'Amber', 'hex': '#D97706'},
    {'name': 'Violet', 'hex': '#7C3AED'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _termsController.dispose();
    _signatureLabelController.dispose();
    _watermarkController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(pdfTemplateRepositoryProvider);
      final setting = await repo.getSetting(_selectedDocType);
      setState(() {
        _templateTheme = setting.templateTheme;
        _primaryColor = setting.primaryColor;
        _headerLayout = setting.headerLayout;
        _showGstColumns = setting.showGstColumns;
        _showHsnColumn = setting.showHsnColumn;
        _showPaymentQr = setting.showPaymentQr;
        _showTerms = setting.showTerms;
        if (setting.termsAndConditions != null) _termsController.text = setting.termsAndConditions!;
        _showSignature = setting.showSignature;
        if (setting.signatureLabel != null) _signatureLabelController.text = setting.signatureLabel!;
        if (setting.watermarkText != null) _watermarkController.text = setting.watermarkText!;
      });
    } catch (_) {
      // Use defaults if load fails
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(pdfTemplateRepositoryProvider);
      final dto = PdfTemplateSettingDto(
        documentType: _selectedDocType,
        templateTheme: _templateTheme,
        primaryColor: _primaryColor,
        headerLayout: _headerLayout,
        showGstColumns: _showGstColumns,
        showHsnColumn: _showHsnColumn,
        showPaymentQr: _showPaymentQr,
        showTerms: _showTerms,
        termsAndConditions: _termsController.text.trim().isNotEmpty ? _termsController.text.trim() : null,
        showSignature: _showSignature,
        signatureLabel: _signatureLabelController.text.trim().isNotEmpty ? _signatureLabelController.text.trim() : null,
        watermarkText: _watermarkController.text.trim().isNotEmpty ? _watermarkController.text.trim() : null,
      );

      await repo.saveSetting(dto);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_selectedDocType PDF template saved successfully!'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return KColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _parseHex(_primaryColor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Template Customizer'),
        actions: [
          KButton.primary(
            label: _isSaving ? 'Saving…' : 'Save Template',
            icon: Icons.check,
            onPressed: _isSaving ? null : _saveSettings,
          ),
          KSpacing.hGapSm,
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Controls Form
                    Expanded(
                      flex: isWide ? 5 : 12,
                      child: ListView(
                        padding: KSpacing.pagePadding,
                        children: [
                          // Document Type Tab Bar
                          _buildDocTypeSelector(),
                          KSpacing.vGapLg,

                          // Theme Choice
                          Text('Document Theme', style: KTypography.labelLarge),
                          KSpacing.vGapSm,
                          _buildThemeSelector(),
                          KSpacing.vGapLg,

                          // Color Palette
                          Text('Brand Accent Color', style: KTypography.labelLarge),
                          KSpacing.vGapSm,
                          _buildColorPicker(),
                          KSpacing.vGapLg,

                          // Header Layout
                          Text('Header Layout', style: KTypography.labelLarge),
                          KSpacing.vGapSm,
                          _buildHeaderLayoutSelector(),
                          KSpacing.vGapLg,

                          // Elements & Column Toggles
                          Text('Columns & Document Elements', style: KTypography.labelLarge),
                          KSpacing.vGapSm,
                          KCard(
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Show GST Split (CGST / SGST / IGST)'),
                                  subtitle: const Text('Separate columns for intra/interstate tax lines'),
                                  value: _showGstColumns,
                                  activeThumbColor: themeColor,
                                  onChanged: (v) => setState(() => _showGstColumns = v),
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text('Show HSN / SAC Code Column'),
                                  subtitle: const Text('Required on Indian B2B GST tax invoices'),
                                  value: _showHsnColumn,
                                  activeThumbColor: themeColor,
                                  onChanged: (v) => setState(() => _showHsnColumn = v),
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text('Show Dynamic Payment QR Code'),
                                  subtitle: const Text('Instant UPI payment QR embedded in invoice bottom'),
                                  value: _showPaymentQr,
                                  activeThumbColor: themeColor,
                                  onChanged: (v) => setState(() => _showPaymentQr = v),
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text('Show Terms & Conditions'),
                                  value: _showTerms,
                                  activeThumbColor: themeColor,
                                  onChanged: (v) => setState(() => _showTerms = v),
                                ),
                                const Divider(),
                                SwitchListTile(
                                  title: const Text('Show Authorized Signature Block'),
                                  value: _showSignature,
                                  activeThumbColor: themeColor,
                                  onChanged: (v) => setState(() => _showSignature = v),
                                ),
                              ],
                            ),
                          ),
                          KSpacing.vGapLg,

                          // Custom Text Fields
                          if (_showTerms) ...[
                            KTextField(
                              controller: _termsController,
                              label: 'Terms & Conditions Text',
                              maxLines: 3,
                              onChanged: (_) => setState(() {}),
                            ),
                            KSpacing.vGapMd,
                          ],

                          if (_showSignature) ...[
                            KTextField(
                              controller: _signatureLabelController,
                              label: 'Signature Block Title',
                              hint: 'Authorized Signatory',
                              onChanged: (_) => setState(() {}),
                            ),
                            KSpacing.vGapMd,
                          ],

                          KTextField(
                            controller: _watermarkController,
                            label: 'Document Watermark / Header Badge',
                            hint: 'e.g. ORIGINAL FOR RECIPIENT',
                            onChanged: (_) => setState(() {}),
                          ),
                          KSpacing.vGapXl,
                        ],
                      ),
                    ),

                    // Right: Live Document Preview Canvas
                    if (isWide) ...[
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 7,
                        child: Container(
                          color: const Color(0xFFE5E7EB),
                          padding: const EdgeInsets.all(24),
                          child: SingleChildScrollView(
                            child: Center(
                              child: _buildLiveDocumentPreview(themeColor),
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

  Widget _buildDocTypeSelector() {
    final types = [
      {'key': 'INVOICE', 'label': 'Sales Invoice'},
      {'key': 'QUOTATION', 'label': 'Quotation'},
      {'key': 'BILL', 'label': 'Purchase Bill'},
      {'key': 'DELIVERY_CHALLAN', 'label': 'Delivery Challan'},
    ];

    return Wrap(
      spacing: 8,
      children: types.map((t) {
        final isSel = _selectedDocType == t['key'];
        return ChoiceChip(
          label: Text(t['label']!),
          selected: isSel,
          onSelected: (_) {
            setState(() => _selectedDocType = t['key']!);
            _loadSettings();
          },
        );
      }).toList(),
    );
  }

  Widget _buildThemeSelector() {
    final themes = [
      {'key': 'CLASSIC', 'title': 'Classic Corporate', 'desc': 'Clean borders & structured lines'},
      {'key': 'MODERN', 'title': 'Modern Bold', 'desc': 'Full accent header & rounded cards'},
      {'key': 'MINIMAL', 'title': 'Clean Minimal', 'desc': 'Airy typography & subtle dividers'},
      {'key': 'COMPACT_THERMAL', 'title': 'Compact Thermal', 'desc': 'High density single page'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: themes.map((th) {
        final isSel = _templateTheme == th['key'];
        return InkWell(
          onTap: () => setState(() => _templateTheme = th['key']!),
          borderRadius: KSpacing.borderRadiusMd,
          child: Container(
            width: 170,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSel ? KColors.primary.withValues(alpha: 0.1) : KColors.surface,
              border: Border.all(color: isSel ? KColors.primary : KColors.border, width: isSel ? 2 : 1),
              borderRadius: KSpacing.borderRadiusMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(th['title']!, style: KTypography.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                KSpacing.vGapXs,
                Text(th['desc']!, style: KTypography.bodySmall.copyWith(color: KColors.textHint, fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      children: _colorPalette.map((c) {
        final isSel = _primaryColor == c['hex'];
        final color = _parseHex(c['hex']!);
        return InkWell(
          onTap: () => setState(() => _primaryColor = c['hex']!),
          customBorder: const CircleBorder(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 2),
              boxShadow: isSel ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)] : null,
            ),
            child: isSel ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeaderLayoutSelector() {
    final layouts = [
      {'key': 'LOGO_LEFT', 'label': 'Logo Left', 'icon': Icons.format_align_left},
      {'key': 'LOGO_CENTER', 'label': 'Logo Center', 'icon': Icons.format_align_center},
      {'key': 'LOGO_RIGHT', 'label': 'Logo Right', 'icon': Icons.format_align_right},
    ];

    return Row(
      children: layouts.map((l) {
        final isSel = _headerLayout == l['key'];
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _headerLayout = l['key'] as String),
              borderRadius: KSpacing.borderRadiusSm,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? KColors.primary.withValues(alpha: 0.1) : KColors.surface,
                  border: Border.all(color: isSel ? KColors.primary : KColors.border, width: isSel ? 2 : 1),
                  borderRadius: KSpacing.borderRadiusSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(l['icon'] as IconData, size: 18, color: isSel ? KColors.primary : KColors.textSecondary),
                    KSpacing.hGapXs,
                    Text(l['label'] as String, style: KTypography.labelSmall),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLiveDocumentPreview(Color themeColor) {
    return Container(
      width: 540,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Watermark / Header Badge
          if (_watermarkController.text.trim().isNotEmpty)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: themeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _watermarkController.text.trim(),
                  style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ),

          // Header
          if (_templateTheme == 'MODERN')
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KATASTICHO HEALTHCARE LTD',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('GSTIN: 27AABCK1234F1Z5 · Maharashtra',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
                    ],
                  ),
                  Text(_selectedDocType,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: _headerLayout == 'LOGO_CENTER'
                  ? MainAxisAlignment.center
                  : _headerLayout == 'LOGO_RIGHT'
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.spaceBetween,
              children: [
                if (_headerLayout != 'LOGO_RIGHT') ...[
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.business, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KATASTICHO HEALTHCARE',
                              style: TextStyle(color: themeColor, fontWeight: FontWeight.w800, fontSize: 12)),
                          const Text('GSTIN: 27AABCK1234F1Z5', style: TextStyle(color: Colors.black54, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_selectedDocType,
                        style: TextStyle(color: themeColor, fontWeight: FontWeight.w900, fontSize: 14)),
                    const Text('No: INV-2026-0891', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    const Text('Date: 31 Aug 2026', style: TextStyle(fontSize: 9, color: Colors.black54)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          const Divider(height: 1),
          const SizedBox(height: 10),

          // Bill To Block
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Billed To:', style: TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.w600)),
                  Text('Apex Chemist & Druggists', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('GSTIN: 27AABCU9876E1Z2 · Mumbai, MH', style: TextStyle(fontSize: 9, color: Colors.black87)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Place of Supply: 27-Maharashtra', style: TextStyle(fontSize: 9, color: Colors.black87)),
                  const Text('Due Date: 15 Sep 2026', style: TextStyle(fontSize: 9, color: Colors.black87)),
                  Text('Payment Terms: Net 15', style: TextStyle(fontSize: 9, color: themeColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Table
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  color: _templateTheme == 'MODERN' ? themeColor.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      const Expanded(flex: 4, child: Text('Item Description', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                      if (_showHsnColumn)
                        const Expanded(flex: 2, child: Text('HSN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                      if (_showGstColumns)
                        const Expanded(flex: 2, child: Text('GST %', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                      const Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Table Rows
                _buildSampleRow('Augmentin 625mg Strip', '300420', '10.0', '₹ 180.00', '12%', '₹ 1,800.00'),
                const Divider(height: 1),
                _buildSampleRow('Paracetamol 650mg Box', '300490', '5.0', '₹ 250.00', '12%', '₹ 1,250.00'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Total & QR Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // QR Code
              if (_showPaymentQr)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        color: Colors.black87,
                        child: const Icon(Icons.qr_code, color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scan & Pay UPI', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          Text('katasticho@icici', style: TextStyle(fontSize: 8, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),

              // Subtotal / Total Calculation
              SizedBox(
                width: 180,
                child: Column(
                  children: [
                    _buildSummaryRow('Taxable Value', '₹ 3,050.00'),
                    if (_showGstColumns) ...[
                      _buildSummaryRow('CGST (6%)', '₹ 183.00'),
                      _buildSummaryRow('SGST (6%)', '₹ 183.00'),
                    ],
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: themeColor)),
                        Text('₹ 3,416.00', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: themeColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Terms & Signature
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_showTerms && _termsController.text.trim().isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Terms & Conditions:', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black45)),
                      Text(_termsController.text.trim(), style: const TextStyle(fontSize: 8, color: Colors.black54)),
                    ],
                  ),
                )
              else
                const Spacer(),

              if (_showSignature)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(width: 100, height: 1, color: Colors.black38),
                    const SizedBox(height: 4),
                    Text(
                      _signatureLabelController.text.trim().isNotEmpty ? _signatureLabelController.text.trim() : 'Authorized Signatory',
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSampleRow(String item, String hsn, String qty, String rate, String gst, String amt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(item, style: const TextStyle(fontSize: 9))),
          if (_showHsnColumn) Expanded(flex: 2, child: Text(hsn, style: const TextStyle(fontSize: 9, color: Colors.black54))),
          Expanded(flex: 1, child: Text(qty, textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
          Expanded(flex: 2, child: Text(rate, textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
          if (_showGstColumns) Expanded(flex: 2, child: Text(gst, textAlign: TextAlign.right, style: const TextStyle(fontSize: 9))),
          Expanded(flex: 2, child: Text(amt, textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.black54)),
          Text(value, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}