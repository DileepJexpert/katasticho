import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_date_picker.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../data/scheme_models.dart';
import '../data/scheme_repository.dart';

class SchemeListScreen extends ConsumerWidget {
  const SchemeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemesAsync = ref.watch(schemesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade Scheme Matrix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Live Scheme Simulator',
            onPressed: () => _showSimulatorSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Scheme',
            onPressed: () => _showCreateSheet(context, ref),
          ),
        ],
      ),
      body: schemesAsync.when(
        loading: () => const KLoading(),
        error: (err, _) => KErrorView(
          message: 'Failed to load trade schemes: $err',
          onRetry: () => ref.invalidate(schemesProvider),
        ),
        data: (schemes) {
          if (schemes.isEmpty) {
            return KEmptyState(
              icon: Icons.local_offer_outlined,
              title: 'No Trade Schemes Found',
              subtitle: 'Configure multi-tier schemes (10+1, Half Schemes, Net Rates)',
              actionLabel: 'Create Trade Scheme',
              onAction: () => _showCreateSheet(context, ref),
            );
          }
          return ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: schemes.length,
            separatorBuilder: (_, __) => KSpacing.vGapSm,
            itemBuilder: (context, i) {
              final scheme = SchemeModel.fromJson(schemes[i]);
              return _SchemeCard(
                scheme: scheme,
                onDelete: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete Scheme'),
                      content: Text('Delete "${scheme.name}"? This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: KColors.error),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(schemeRepositoryProvider).deleteScheme(scheme.id);
                    ref.invalidate(schemesProvider);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateSchemeSheet(onCreated: () {
        ref.invalidate(schemesProvider);
      }),
    );
  }

  void _showSimulatorSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _SchemeSimulatorSheet(),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final SchemeModel scheme;
  final VoidCallback onDelete;

  const _SchemeCard({required this.scheme, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = scheme.schemeType.toUpperCase();
    final isBuyX = type == 'BUY_X_GET_Y' || type == 'HALF_FULL_SCHEME';
    final isNetRate = type == 'SPECIAL_NET_RATE';

    String badgeText;
    Color badgeColor;
    if (isNetRate) {
      badgeText = 'NET RATE';
      badgeColor = KColors.secondary;
    } else if (isBuyX) {
      badgeText = '${scheme.buyQuantity?.toInt() ?? 10}+${scheme.freeQuantity?.toInt() ?? 1}';
      badgeColor = Colors.orange;
    } else {
      badgeText = '${scheme.discountPercent?.toInt() ?? 0}%';
      badgeColor = KColors.primary;
    }

    String summary;
    if (isNetRate) {
      summary = 'Special Company Net Rate @ ₹${scheme.specialNetRate ?? 0}/unit (Min ${scheme.minOrderQuantity.toInt()} units)';
    } else if (isBuyX) {
      summary = 'Buy ${scheme.buyQuantity?.toInt()} Get ${scheme.freeQuantity?.toInt()} Free';
      if (scheme.allowHalfScheme) {
        summary += ' · Half Scheme Allowed';
      }
    } else {
      summary = '${scheme.discountPercent}% off (Min ${scheme.minOrderQuantity.toInt()} units)';
    }

    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeText,
              style: KTypography.labelMedium.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(scheme.name, style: KTypography.labelLarge),
                    ),
                    if (!scheme.active)
                      const KStatusChip(
                        status: 'CANCELLED',
                        label: 'Inactive',
                      ),
                  ],
                ),
                KSpacing.vGapXs,
                Text(summary, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                if (scheme.itemName != null) ...[
                  KSpacing.vGapXs,
                  Text('Item: ${scheme.itemName}', style: KTypography.caption.copyWith(fontWeight: FontWeight.w600)),
                ],
                KSpacing.vGapXs,
                Wrap(
                  spacing: 6,
                  children: [
                    if (scheme.companySubsidyPercent > 0)
                      KStatusChip(
                        status: 'ACTIVE',
                        label: 'Company Subsidy: ${scheme.companySubsidyPercent.toInt()}%',
                      ),
                    if (scheme.maxFreeQuantityCap != null)
                      KStatusChip(
                        status: 'DRAFT',
                        label: 'Max Free Cap: ${scheme.maxFreeQuantityCap?.toInt()}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: KColors.error),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class _SchemeSimulatorSheet extends ConsumerStatefulWidget {
  const _SchemeSimulatorSheet();

  @override
  ConsumerState<_SchemeSimulatorSheet> createState() => _SchemeSimulatorSheetState();
}

class _SchemeSimulatorSheetState extends ConsumerState<_SchemeSimulatorSheet> {
  Map<String, dynamic>? _selectedItem;
  final _qtyCtrl = TextEditingController(text: '10');
  final _priceCtrl = TextEditingController(text: '100.00');
  SchemeCalculationResult? _result;
  bool _calculating = false;
  String? _error;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _simulate() async {
    if (_selectedItem == null) {
      setState(() => _error = 'Please select an item to simulate');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text) ?? 0.0;
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    if (qty <= 0 || price <= 0) {
      setState(() => _error = 'Enter valid quantity and base price');
      return;
    }

    setState(() {
      _calculating = true;
      _error = null;
    });

    try {
      final repo = ref.read(schemeRepositoryProvider);
      final res = await repo.evaluateScheme(
        itemId: _selectedItem!['id'].toString(),
        quantity: qty,
        unitPrice: price,
      );
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) setState(() => _error = 'Calculation error: $e');
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: KSpacing.lg,
        right: KSpacing.lg,
        top: KSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Live Scheme & Subsidy Simulator', style: KTypography.h3),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            KSpacing.vGapXs,
            Text(
              'Test any quantity to view live Free Goods vs Cash Discount conversion and Manufacturer Subsidy breakdown.',
              style: KTypography.caption.copyWith(color: KColors.textSecondary),
            ),
            KSpacing.vGapMd,

            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: KColors.error, fontSize: 12)),
              KSpacing.vGapSm,
            ],

            // Item Picker
            InkWell(
              onTap: () async {
                final picked = await showItemPicker(context);
                if (picked != null) {
                  setState(() {
                    _selectedItem = picked;
                    final sp = (picked['sellingPrice'] ?? picked['unitPrice'] as num?)?.toDouble();
                    if (sp != null && sp > 0) {
                      _priceCtrl.text = sp.toStringAsFixed(2);
                    }
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Select Product for Simulation'),
                child: Text(
                  _selectedItem?['name']?.toString() ?? 'Tap to pick product',
                  style: _selectedItem == null
                      ? KTypography.bodySmall.copyWith(color: KColors.textSecondary)
                      : KTypography.bodyMedium,
                ),
              ),
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Order Quantity',
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _simulate(),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KTextField(
                    label: 'Base PTR / Rate (₹)',
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _simulate(),
                  ),
                ),
              ],
            ),
            KSpacing.vGapMd,

            KButton(
              label: _calculating ? 'Evaluating Scheme...' : 'Run Simulation',
              icon: Icons.flash_on,
              isLoading: _calculating,
              onPressed: _simulate,
            ),
            KSpacing.vGapMd,

            if (_result != null) ...[
              KCard(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Simulation Result', style: KTypography.labelLarge),
                        KStatusChip(
                          status: _result!.isHalfSchemeApplied ? 'PENDING' : 'ACTIVE',
                          label: _result!.schemeType,
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    Text(_result!.explanation, style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: KColors.primary)),
                    KSpacing.vGapSm,
                    const Divider(height: 1),
                    KSpacing.vGapSm,
                    _SimRow('Billed Quantity', '${_result!.orderedQuantity.toInt()} units'),
                    if (_result!.freeQuantity > 0)
                      _SimRow('Free Goods Provided', '+${_result!.freeQuantity.toInt()} units (FREE)'),
                    if (_result!.discountPercent > 0)
                      _SimRow('Trade Discount %', '${_result!.discountPercent}% (-₹${_result!.discountAmount.toStringAsFixed(2)})'),
                    _SimRow('Effective Net Unit Cost', '₹${_result!.effectiveUnitPrice.toStringAsFixed(2)} / unit'),
                    _SimRow('Total Invoice Line Amount', '₹${_result!.totalLineAmount.toStringAsFixed(2)}'),
                    const Divider(height: 1),
                    KSpacing.vGapSm,
                    _SimRow('Company Reimbursable Share', '₹${_result!.companyFundedAmount.toStringAsFixed(2)}', isBold: true),
                    _SimRow('Distributor Net Absorption', '₹${_result!.distributorFundedAmount.toStringAsFixed(2)}'),
                  ],
                ),
              ),
              KSpacing.vGapLg,
            ],
          ],
        ),
      ),
    );
  }
}

class _SimRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SimRow(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
          Text(value, style: isBold ? KTypography.labelMedium.copyWith(fontWeight: FontWeight.w700) : KTypography.caption.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CreateSchemeSheet extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateSchemeSheet({required this.onCreated});

  @override
  ConsumerState<_CreateSchemeSheet> createState() => _CreateSchemeSheetState();
}

class _CreateSchemeSheetState extends ConsumerState<_CreateSchemeSheet> {
  final _nameCtl = TextEditingController();
  final _buyQtyCtl = TextEditingController(text: '10');
  final _freeQtyCtl = TextEditingController(text: '1');
  final _discountPctCtl = TextEditingController();
  final _minQtyCtl = TextEditingController();
  final _halfMinQtyCtl = TextEditingController(text: '5');
  final _subsidyPctCtl = TextEditingController(text: '100');
  final _netRateCtl = TextEditingController();
  final _freeCapCtl = TextEditingController();

  String _schemeType = 'BUY_X_GET_Y';
  Map<String, dynamic>? _pickedItem;
  DateTime? _validFrom;
  DateTime? _validTo;
  bool _allowHalfScheme = true;
  bool _active = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameCtl.dispose();
    _buyQtyCtl.dispose();
    _freeQtyCtl.dispose();
    _discountPctCtl.dispose();
    _minQtyCtl.dispose();
    _halfMinQtyCtl.dispose();
    _subsidyPctCtl.dispose();
    _netRateCtl.dispose();
    _freeCapCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtl.text.trim().isEmpty) {
      setState(() => _error = 'Scheme name is required');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final body = <String, dynamic>{
        'name': _nameCtl.text.trim(),
        'schemeType': _schemeType,
        'active': _active,
        'allowHalfScheme': _allowHalfScheme,
        'companySubsidyPercent': double.tryParse(_subsidyPctCtl.text) ?? 100.0,
        if (_pickedItem != null) 'itemId': _pickedItem!['id'],
        if (_validFrom != null) 'validFrom': _validFrom!.toIso8601String().split('T').first,
        if (_validTo != null) 'validTo': _validTo!.toIso8601String().split('T').first,
      };

      if (_schemeType == 'BUY_X_GET_Y' || _schemeType == 'HALF_FULL_SCHEME') {
        body['buyQuantity'] = double.tryParse(_buyQtyCtl.text) ?? 10;
        body['freeQuantity'] = double.tryParse(_freeQtyCtl.text) ?? 1;
        if (_allowHalfScheme && _halfMinQtyCtl.text.isNotEmpty) {
          body['halfSchemeMinQty'] = double.tryParse(_halfMinQtyCtl.text);
        }
        if (_freeCapCtl.text.isNotEmpty) {
          body['maxFreeQuantityCap'] = double.tryParse(_freeCapCtl.text);
        }
      } else if (_schemeType == 'SPECIAL_NET_RATE') {
        body['specialNetRate'] = double.tryParse(_netRateCtl.text) ?? 0.0;
        body['minOrderQuantity'] = double.tryParse(_minQtyCtl.text) ?? 1;
      } else {
        body['discountPercent'] = double.tryParse(_discountPctCtl.text) ?? 0;
        if (_minQtyCtl.text.isNotEmpty) {
          body['minOrderQuantity'] = double.tryParse(_minQtyCtl.text) ?? 0;
        }
      }

      await ref.read(schemeRepositoryProvider).createScheme(body);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to create scheme: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Multi-Tier Trade Scheme', style: KTypography.h3),
            KSpacing.vGapMd,
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: KColors.error, fontSize: 12)),
              KSpacing.vGapSm,
            ],
            KTextField(label: 'Scheme Name *', hint: 'e.g. Augmentin 10+1 Scheme', controller: _nameCtl),
            KSpacing.vGapSm,
            DropdownButtonFormField<String>(
              initialValue: _schemeType,
              decoration: const InputDecoration(labelText: 'Scheme Classification'),
              items: const [
                DropdownMenuItem(value: 'BUY_X_GET_Y', child: Text('Buy X Get Y Free (10+1 Full Scheme)')),
                DropdownMenuItem(value: 'HALF_FULL_SCHEME', child: Text('Half & Full Scheme (Auto Cash Discount)')),
                DropdownMenuItem(value: 'PERCENT_DISCOUNT', child: Text('Percentage Trade Discount')),
                DropdownMenuItem(value: 'SPECIAL_NET_RATE', child: Text('Special Company Net Rate (Fixed Price)')),
              ],
              onChanged: (v) => setState(() => _schemeType = v!),
            ),
            KSpacing.vGapSm,

            if (_schemeType == 'BUY_X_GET_Y' || _schemeType == 'HALF_FULL_SCHEME') ...[
              Row(
                children: [
                  Expanded(child: KTextField(label: 'Buy Qty', controller: _buyQtyCtl, keyboardType: TextInputType.number)),
                  KSpacing.hGapSm,
                  Expanded(child: KTextField(label: 'Free Qty', controller: _freeQtyCtl, keyboardType: TextInputType.number)),
                ],
              ),
              KSpacing.vGapSm,
              SwitchListTile(
                title: const Text('Allow Half Scheme Conversion'),
                subtitle: const Text('Converts free goods to equivalent cash discount if customer buys half slab'),
                value: _allowHalfScheme,
                onChanged: (v) => setState(() => _allowHalfScheme = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (_allowHalfScheme) ...[
                KTextField(label: 'Half Scheme Min Quantity', hint: 'e.g. 5', controller: _halfMinQtyCtl, keyboardType: TextInputType.number),
                KSpacing.vGapSm,
              ],
              KTextField(label: 'Max Free Goods Cap per Order (optional)', hint: 'e.g. 10', controller: _freeCapCtl, keyboardType: TextInputType.number),
              KSpacing.vGapSm,
            ] else if (_schemeType == 'SPECIAL_NET_RATE') ...[
              Row(
                children: [
                  Expanded(child: KTextField(label: 'Special Net Rate (₹)', controller: _netRateCtl, keyboardType: TextInputType.number)),
                  KSpacing.hGapSm,
                  Expanded(child: KTextField(label: 'Min Order Qty', controller: _minQtyCtl, keyboardType: TextInputType.number)),
                ],
              ),
              KSpacing.vGapSm,
            ] else ...[
              Row(
                children: [
                  Expanded(child: KTextField(label: 'Discount %', controller: _discountPctCtl, keyboardType: TextInputType.number)),
                  KSpacing.hGapSm,
                  Expanded(child: KTextField(label: 'Min Order Qty', controller: _minQtyCtl, keyboardType: TextInputType.number)),
                ],
              ),
              KSpacing.vGapSm,
            ],

            KTextField(
              label: 'Company Reimbursement Subsidy %',
              hint: '100% = Manufacturer absorbs full cost',
              controller: _subsidyPctCtl,
              keyboardType: TextInputType.number,
            ),
            KSpacing.vGapSm,

            InkWell(
              onTap: () async {
                final picked = await showItemPicker(context);
                if (picked != null) setState(() => _pickedItem = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Item (optional — leave blank for all products)'),
                child: Text(
                  _pickedItem?['name']?.toString() ?? 'Tap to pick product',
                  style: _pickedItem == null ? KTypography.bodySmall.copyWith(color: KColors.textSecondary) : KTypography.bodyMedium,
                ),
              ),
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KDatePicker(
                    label: 'Valid From',
                    value: _validFrom ?? DateTime.now(),
                    onChanged: (d) => setState(() => _validFrom = d),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KDatePicker(
                    label: 'Valid To',
                    value: _validTo ?? DateTime.now().add(const Duration(days: 365)),
                    onChanged: (d) => setState(() => _validTo = d),
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,

            SwitchListTile(
              title: const Text('Active Scheme'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              contentPadding: EdgeInsets.zero,
            ),
            KSpacing.vGapMd,

            KButton(
              label: 'Save Trade Scheme',
              icon: Icons.save_outlined,
              onPressed: _submit,
              isLoading: _isSubmitting,
              fullWidth: true,
            ),
            KSpacing.vGapLg,
          ],
        ),
      ),
    );
  }
}
