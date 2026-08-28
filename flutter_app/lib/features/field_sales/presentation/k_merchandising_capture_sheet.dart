import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/field_sales_repository.dart';

class KMerchandisingCaptureSheet extends ConsumerStatefulWidget {
  final String fieldVisitId;
  final String routeExecutionId;
  final String contactId;
  final String customerName;
  final VoidCallback onSaved;

  const KMerchandisingCaptureSheet({
    super.key,
    required this.fieldVisitId,
    required this.routeExecutionId,
    required this.contactId,
    required this.customerName,
    required this.onSaved,
  });

  @override
  ConsumerState<KMerchandisingCaptureSheet> createState() =>
      _KMerchandisingCaptureSheetState();
}

class _KMerchandisingCaptureSheetState
    extends ConsumerState<KMerchandisingCaptureSheet> {
  final _formKey = GlobalKey<FormState>();

  final _photoUrlCtrl = TextEditingController();
  final _shelfShareCtrl = TextEditingController(text: '50');
  final _facingCountCtrl = TextEditingController(text: '6');
  final _competitorsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _auditType = 'PRIMARY_SHELF';
  String _compliance = 'COMPLIANT';
  bool _isStockOut = false;
  bool _isSubmitting = false;

  static const List<Map<String, String>> _auditTypes = [
    {'value': 'PRIMARY_SHELF', 'label': 'Primary Shelf'},
    {'value': 'SECONDARY_DISPLAY', 'label': 'Secondary Display / Endcap'},
    {'value': 'COMPETITOR_PRESENCE', 'label': 'Competitor Space'},
    {'value': 'POSM_POSTER', 'label': 'POSM Poster / Sticker'},
    {'value': 'PROMOTIONAL_BANNER', 'label': 'Promotional Banner'},
  ];

  static const List<Map<String, String>> _complianceOptions = [
    {'value': 'COMPLIANT', 'label': 'Compliant (Per Planogram)'},
    {'value': 'PARTIAL', 'label': 'Partially Compliant'},
    {'value': 'NON_COMPLIANT', 'label': 'Non-Compliant (Wrong Slot)'},
  ];

  @override
  void dispose() {
    _photoUrlCtrl.dispose();
    _shelfShareCtrl.dispose();
    _facingCountCtrl.dispose();
    _competitorsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final shelfShare = double.tryParse(_shelfShareCtrl.text.trim());
      final facingCount = int.tryParse(_facingCountCtrl.text.trim());

      final payload = {
        'fieldVisitId': widget.fieldVisitId,
        'routeExecutionId': widget.routeExecutionId,
        'contactId': widget.contactId,
        'auditType': _auditType,
        'photoUrl': _photoUrlCtrl.text.trim().isEmpty ? null : _photoUrlCtrl.text.trim(),
        'shelfSharePct': shelfShare,
        'facingCount': facingCount,
        'isStockOut': _isStockOut,
        'competitorBrandNames': _competitorsCtrl.text.trim().isEmpty ? null : _competitorsCtrl.text.trim(),
        'planogramCompliance': _compliance,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      await ref.read(fieldSalesRepositoryProvider).recordMerchandisingAudit(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shelf merchandising audit recorded successfully'),
          ),
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record audit: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      padding: EdgeInsets.only(
        top: KSpacing.lg,
        left: KSpacing.lg,
        right: KSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + KSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shelf & Merchandising Audit', style: KTypography.h3),
                        KSpacing.vGapXs,
                        Text(
                          widget.customerName,
                          style: KTypography.bodySmall.copyWith(color: KColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              KSpacing.vGapMd,

              // Audit Type
              Text('Audit Type', style: KTypography.labelLarge),
              KSpacing.vGapXs,
              DropdownButtonFormField<String>(
                initialValue: _auditType,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                ),
                items: _auditTypes.map((t) {
                  return DropdownMenuItem(value: t['value'], child: Text(t['label']!));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _auditType = v);
                },
              ),
              KSpacing.vGapSm,

              // Photo URL
              KTextField(
                controller: _photoUrlCtrl,
                label: 'Shelf Photo URL / Storage Link',
                hint: 'https://storage.googleapis.com/... or cloud photo URL',
                prefixIcon: Icons.camera_alt_outlined,
              ),
              KSpacing.vGapSm,

              Row(
                children: [
                  Expanded(
                    child: KTextField(
                      controller: _shelfShareCtrl,
                      label: 'Our Shelf Share (%)',
                      hint: '0 - 100',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      prefixIcon: Icons.pie_chart_outline,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final num = double.tryParse(v);
                          if (num == null || num < 0 || num > 100) {
                            return 'Enter 0-100';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: KTextField(
                      controller: _facingCountCtrl,
                      label: 'Facing Count (Units)',
                      hint: 'e.g. 6',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.view_column_outlined,
                    ),
                  ),
                ],
              ),
              KSpacing.vGapSm,

              // Planogram Compliance
              Text('Planogram Placement Compliance', style: KTypography.labelLarge),
              KSpacing.vGapXs,
              DropdownButtonFormField<String>(
                initialValue: _compliance,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: KSpacing.md, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                ),
                items: _complianceOptions.map((c) {
                  return DropdownMenuItem(value: c['value'], child: Text(c['label']!));
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _compliance = v);
                },
              ),
              KSpacing.vGapSm,

              // Competitor Brands
              KTextField(
                controller: _competitorsCtrl,
                label: 'Competitor Brands Observed',
                hint: 'e.g. Cipla, Sun Pharma, Dabur',
                prefixIcon: Icons.storefront_outlined,
              ),
              KSpacing.vGapSm,

              // Notes
              KTextField(
                controller: _notesCtrl,
                label: 'Field Observations / Remarks',
                hint: 'e.g. Top shelf eye-level space secured, POP banner placed near checkout',
                maxLines: 2,
              ),
              KSpacing.vGapSm,

              // Stock out switch
              SwitchListTile.adaptive(
                title: const Text('Stock-Out Observed on Shelf'),
                subtitle: const Text('Check if our product was completely out of stock on customer shelf'),
                value: _isStockOut,
                activeTrackColor: KColors.error,
                onChanged: (v) => setState(() => _isStockOut = v),
              ),

              KSpacing.vGapLg,
              SizedBox(
                width: double.infinity,
                child: KButton(
                  label: _isSubmitting ? 'Saving...' : 'Record Merchandising Audit',
                  icon: Icons.check,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
