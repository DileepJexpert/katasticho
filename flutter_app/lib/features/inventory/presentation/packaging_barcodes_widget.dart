import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/packaging_barcode_models.dart';
import '../data/packaging_barcode_repository.dart';

class PackagingBarcodesWidget extends ConsumerWidget {
  final String itemId;
  final String itemName;
  final String? baseUom;

  const PackagingBarcodesWidget({
    super.key,
    required this.itemId,
    required this.itemName,
    this.baseUom,
  });

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackagingBarcodeSheet(
        itemId: itemId,
        baseUom: baseUom ?? 'PCS',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barcodesAsync = ref.watch(itemPackagingBarcodesProvider(itemId));

    return barcodesAsync.when(
      loading: () => const KLoading(),
      error: (err, _) => KErrorView(
        message: 'Failed to load packaging barcodes: $err',
        onRetry: () => ref.invalidate(itemPackagingBarcodesProvider(itemId)),
      ),
      data: (barcodes) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Packaging Hierarchy Barcodes', style: KTypography.labelLarge),
                    KSpacing.vGapXs,
                    Text(
                      'Scan carton or master case barcodes to auto-populate multiplier quantities.',
                      style: KTypography.caption.copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
                KButton(
                  label: 'Add Packaging Tier',
                  icon: Icons.add_link,
                  onPressed: () => _showAddSheet(context, ref),
                ),
              ],
            ),
            KSpacing.vGapMd,

            if (barcodes.isEmpty)
              const KEmptyState(
                icon: Icons.qr_code_scanner,
                title: 'No Packaging Hierarchy Barcodes Configured',
                subtitle:
                    'Add outer box, carton, or master case barcodes with conversion factors.',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: barcodes.length,
                separatorBuilder: (_, __) => KSpacing.vGapSm,
                itemBuilder: (context, i) {
                  final b = barcodes[i];
                  return _PackagingTierCard(
                    barcode: b,
                    onDeleted: () =>
                        ref.invalidate(itemPackagingBarcodesProvider(itemId)),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _PackagingTierCard extends ConsumerWidget {
  final PackagingBarcodeModel barcode;
  final VoidCallback onDeleted;

  const _PackagingTierCard({
    required this.barcode,
    required this.onDeleted,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Packaging Barcode?'),
        content: Text('Remove ${barcode.packagingLevel} barcode ${barcode.barcode}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: KColors.error)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref
            .read(packagingBarcodeRepositoryProvider)
            .deletePackagingBarcode(barcode.id);
        onDeleted();
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        children: [
          // Hierarchy Multiplier Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: KColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Text(
                  '× ${barcode.conversionFactor.toStringAsFixed(barcode.conversionFactor.truncateToDouble() == barcode.conversionFactor ? 0 : 2)}',
                  style: KTypography.h2.copyWith(color: KColors.primary),
                ),
                Text(
                  barcode.uomName ?? 'Units',
                  style: KTypography.caption.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          KSpacing.hGapMd,

          // Packaging Level & Barcode Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    KStatusChip(
                      status: barcode.packagingLevel == 'CASE' ||
                              barcode.packagingLevel == 'CARTON'
                          ? 'PAID'
                          : 'SENT',
                      label: barcode.packagingLevel,
                    ),
                    KSpacing.hGapSm,
                    if (barcode.packagingName != null)
                      Text(
                        barcode.packagingName!,
                        style: KTypography.labelLarge,
                      ),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 16, color: KColors.textSecondary),
                    KSpacing.hGapXs,
                    Text(
                      barcode.barcode,
                      style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (barcode.salePrice != null || barcode.mrp != null) ...[
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      if (barcode.salePrice != null) ...[
                        Text('Wholesale: ', style: KTypography.caption),
                        KMoney(barcode.salePrice!),
                        KSpacing.hGapMd,
                      ],
                      if (barcode.mrp != null) ...[
                        Text('Printed MRP: ', style: KTypography.caption),
                        KMoney(barcode.mrp!),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Delete Action Button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: KColors.textHint),
            tooltip: 'Remove Packaging Barcode',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD PACKAGING BARCODE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _PackagingBarcodeSheet extends ConsumerStatefulWidget {
  final String itemId;
  final String baseUom;

  const _PackagingBarcodeSheet({
    required this.itemId,
    required this.baseUom,
  });

  @override
  ConsumerState<_PackagingBarcodeSheet> createState() =>
      _PackagingBarcodeSheetState();
}

class _PackagingBarcodeSheetState extends ConsumerState<_PackagingBarcodeSheet> {
  final _barcodeCtl = TextEditingController();
  final _factorCtl = TextEditingController(text: '10');
  final _nameCtl = TextEditingController(text: 'Master Carton 10x');
  final _uomCtl = TextEditingController(text: 'BOX');
  final _mrpCtl = TextEditingController();
  final _salePriceCtl = TextEditingController();
  String _packagingLevel = 'CARTON';
  bool _isSaving = false;

  @override
  void dispose() {
    _barcodeCtl.dispose();
    _factorCtl.dispose();
    _nameCtl.dispose();
    _uomCtl.dispose();
    _mrpCtl.dispose();
    _salePriceCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final barcode = _barcodeCtl.text.trim();
    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode string is required')),
      );
      return;
    }

    final factor = double.tryParse(_factorCtl.text.trim()) ?? 1.0;

    setState(() => _isSaving = true);
    try {
      final req = CreatePackagingBarcodeRequest(
        barcode: barcode,
        packagingLevel: _packagingLevel,
        packagingName: _nameCtl.text.trim().isNotEmpty ? _nameCtl.text.trim() : null,
        conversionFactor: factor,
        uomName: _uomCtl.text.trim().isNotEmpty ? _uomCtl.text.trim() : null,
        mrp: double.tryParse(_mrpCtl.text.trim()),
        salePrice: double.tryParse(_salePriceCtl.text.trim()),
      );

      await ref
          .read(packagingBarcodeRepositoryProvider)
          .addPackagingBarcode(widget.itemId, req);
      ref.invalidate(itemPackagingBarcodesProvider(widget.itemId));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Packaging hierarchy barcode added!'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Packaging Hierarchy Barcode', style: KTypography.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            KSpacing.vGapMd,

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _packagingLevel,
                    decoration: const InputDecoration(labelText: 'Packaging Level'),
                    items: const [
                      DropdownMenuItem(value: 'UNIT', child: Text('Single Unit / Strip')),
                      DropdownMenuItem(value: 'PACK', child: Text('Intermediate Pack')),
                      DropdownMenuItem(value: 'BOX', child: Text('Inner Box')),
                      DropdownMenuItem(value: 'CARTON', child: Text('Master Carton')),
                      DropdownMenuItem(value: 'CASE', child: Text('Outer Shipper Case')),
                      DropdownMenuItem(value: 'PALLET', child: Text('Warehouse Pallet')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _packagingLevel = v!;
                        if (v == 'PACK') _factorCtl.text = '10';
                        if (v == 'BOX') _factorCtl.text = '20';
                        if (v == 'CARTON') _factorCtl.text = '100';
                        if (v == 'CASE') _factorCtl.text = '500';
                      });
                    },
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  flex: 2,
                  child: KTextField(
                    label: 'Multiplier (x ${widget.baseUom}) *',
                    controller: _factorCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,

            KTextField(
              label: 'Printed Packaging Barcode *',
              hint: 'e.g. 8901234567890 (Scan or type)',
              controller: _barcodeCtl,
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Packaging Label',
                    hint: 'e.g. Shipper Case 24x',
                    controller: _nameCtl,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField(
                    label: 'Package UoM',
                    hint: 'e.g. BOX / CASE',
                    controller: _uomCtl,
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Package MRP (₹)',
                    hint: 'Optional printed MRP',
                    controller: _mrpCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField(
                    label: 'Wholesale Case Rate (₹)',
                    hint: 'Optional bulk price',
                    controller: _salePriceCtl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            KSpacing.vGapLg,

            KButton(
              label: _isSaving ? 'Saving...' : 'Save Packaging Tier',
              icon: Icons.save,
              isLoading: _isSaving,
              onPressed: _save,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
