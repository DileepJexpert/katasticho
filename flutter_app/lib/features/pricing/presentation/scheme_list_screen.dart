import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../data/scheme_repository.dart';

class SchemeListScreen extends ConsumerWidget {
  const SchemeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schemesAsync = ref.watch(schemesProvider);

    return KKeyboardListWrapper(
      itemCount: () => schemesAsync.valueOrNull?.length ?? 0,
      onNew: () => _showCreateSheet(context, ref),
      onRefresh: () => ref.invalidate(schemesProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Scheme Management'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Scheme (N)',
              onPressed: () => _showCreateSheet(context, ref),
            ),
          ],
        ),
        body: schemesAsync.when(
          loading: () => const KLoading(),
          error: (err, _) => KErrorView(
            message: 'Failed to load schemes: $err',
            onRetry: () => ref.invalidate(schemesProvider),
          ),
          data: (schemes) {
            if (schemes.isEmpty) {
              return KEmptyState(
                icon: Icons.local_offer_outlined,
                title: 'No schemes yet',
                subtitle: 'Add pharma schemes like 10+2 or 15% off',
                actionLabel: 'Add Scheme',
                onAction: () => _showCreateSheet(context, ref),
              );
            }
            return ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: schemes.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (context, i) =>
                  _SchemeCard(scheme: schemes[i], onDelete: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Scheme'),
                    content: Text(
                        'Delete "${schemes[i]['name']}"? This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: KColors.error),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(schemeRepositoryProvider)
                      .deleteScheme(schemes[i]['id'].toString());
                  ref.invalidate(schemesProvider);
                }
              }),
            );
          },
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateSchemeSheet(onCreated: () {
        ref.invalidate(schemesProvider);
      }),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final Map<String, dynamic> scheme;
  final VoidCallback onDelete;

  const _SchemeCard({required this.scheme, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = scheme['schemeType']?.toString() ?? '';
    final isBuyXGetY = type == 'BUY_X_GET_Y';
    final active = scheme['active'] == true;
    final itemName = scheme['itemName']?.toString();
    final validFrom = scheme['validFrom']?.toString();
    final validTo = scheme['validTo']?.toString();

    String summary;
    if (isBuyXGetY) {
      final buy = scheme['buyQuantity'];
      final free = scheme['freeQuantity'];
      summary = 'Buy $buy Get $free Free';
    } else {
      final pct = scheme['discountPercent'];
      final min = scheme['minOrderQuantity'];
      summary = '$pct% off${min != null && min != 0 ? ' (min $min units)' : ''}';
    }

    return KCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isBuyXGetY ? Colors.orange : KColors.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isBuyXGetY ? '10+2' : '%',
              style: KTypography.labelLarge.copyWith(
                color: isBuyXGetY ? Colors.orange : KColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(scheme['name']?.toString() ?? '',
                          style: KTypography.labelLarge)),
                  if (!active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KColors.textHint.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Inactive',
                          style: KTypography.labelSmall
                              .copyWith(color: KColors.textSecondary)),
                    ),
                ]),
                KSpacing.vGapXxs,
                Text(summary,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
                if (itemName != null)
                  Text('Item: $itemName',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                if (validFrom != null || validTo != null)
                  Text(
                    '${validFrom ?? '—'} → ${validTo ?? '∞'}',
                    style: KTypography.labelSmall
                        .copyWith(color: KColors.textHint),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: KColors.error),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
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
  String _schemeType = 'BUY_X_GET_Y';
  Map<String, dynamic>? _pickedItem;
  DateTime? _validFrom;
  DateTime? _validTo;
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
        if (_pickedItem != null) 'itemId': _pickedItem!['id'],
        if (_validFrom != null)
          'validFrom': _validFrom!.toIso8601String().split('T').first,
        if (_validTo != null)
          'validTo': _validTo!.toIso8601String().split('T').first,
      };
      if (_schemeType == 'BUY_X_GET_Y') {
        body['buyQuantity'] = double.tryParse(_buyQtyCtl.text) ?? 10;
        body['freeQuantity'] = double.tryParse(_freeQtyCtl.text) ?? 1;
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
      setState(() => _error = 'Failed to create scheme');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Scheme', style: KTypography.h3),
            KSpacing.vGapMd,
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.sm),
                child: KErrorBanner(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null)),
              ),
            KTextField(label: 'Scheme Name', controller: _nameCtl),
            KSpacing.vGapSm,
            DropdownButtonFormField<String>(
              initialValue: _schemeType,
              decoration: const InputDecoration(labelText: 'Scheme Type'),
              items: const [
                DropdownMenuItem(
                    value: 'BUY_X_GET_Y',
                    child: Text('Buy X Get Y Free (10+2)')),
                DropdownMenuItem(
                    value: 'PERCENT_DISCOUNT',
                    child: Text('% Discount on Quantity')),
              ],
              onChanged: (v) => setState(() => _schemeType = v!),
            ),
            KSpacing.vGapSm,
            if (_schemeType == 'BUY_X_GET_Y') ...[
              Row(children: [
                Expanded(
                    child: KTextField(
                        label: 'Buy Qty',
                        controller: _buyQtyCtl,
                        keyboardType: TextInputType.number)),
                KSpacing.hGapSm,
                Expanded(
                    child: KTextField(
                        label: 'Free Qty',
                        controller: _freeQtyCtl,
                        keyboardType: TextInputType.number)),
              ]),
            ] else ...[
              Row(children: [
                Expanded(
                    child: KTextField(
                        label: 'Discount %',
                        controller: _discountPctCtl,
                        keyboardType: TextInputType.number)),
                KSpacing.hGapSm,
                Expanded(
                    child: KTextField(
                        label: 'Min Order Qty',
                        controller: _minQtyCtl,
                        keyboardType: TextInputType.number)),
              ]),
            ],
            KSpacing.vGapSm,
            InkWell(
              onTap: () async {
                final picked = await showItemPicker(context);
                if (picked != null) setState(() => _pickedItem = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Item (optional — leave blank for all)'),
                child: Text(
                  _pickedItem?['name']?.toString() ?? 'Tap to pick item',
                  style: _pickedItem == null
                      ? KTypography.bodySmall
                          .copyWith(color: KColors.textHint)
                      : KTypography.bodyMedium,
                ),
              ),
            ),
            KSpacing.vGapSm,
            Row(children: [
              Expanded(
                child: KDatePicker(
                  label: 'Valid From (optional)',
                  value: _validFrom ?? DateTime.now(),
                  onChanged: (d) => setState(() => _validFrom = d),
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KDatePicker(
                  label: 'Valid To (optional)',
                  value: _validTo ?? DateTime.now().add(const Duration(days: 365)),
                  onChanged: (d) => setState(() => _validTo = d),
                ),
              ),
            ]),
            KSpacing.vGapSm,
            SwitchListTile(
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              contentPadding: EdgeInsets.zero,
            ),
            KSpacing.vGapMd,
            KButton(
              label: 'Save Scheme',
              icon: Icons.save_outlined,
              onPressed: _submit,
              isLoading: _isSubmitting,
              fullWidth: true,
            ),
            KSpacing.vGapMd,
          ],
        ),
      ),
    );
  }
}
