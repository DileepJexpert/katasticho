import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../data/scrap_repository.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ScrapScreen extends ConsumerStatefulWidget {
  const ScrapScreen({super.key});

  @override
  ConsumerState<ScrapScreen> createState() => _ScrapScreenState();
}

class _ScrapScreenState extends ConsumerState<ScrapScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReasonTab = _tabs.index == 1;

    return Scaffold(
      body: Column(
        children: [
          const KListPageHeader(
            title: 'Production Scrap',
          ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Scrap Records'),
              Tab(text: 'Reason Codes'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _ScrapRecordsTab(),
                _ReasonCodesTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isReasonTab
          ? FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showAddReasonCodeSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Reason Code'),
              tooltip: 'Add Reason Code (N)',
            )
          : FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showRecordScrapDialog(context),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Record Scrap'),
              tooltip: 'Record Scrap (N)',
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Record Scrap dialog
  // ---------------------------------------------------------------------------

  Future<void> _showRecordScrapDialog(BuildContext context) async {
    final woCtl = TextEditingController();
    final qtyCtl = TextEditingController();
    final jobCardCtl = TextEditingController();
    final notesCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    EntityOption? reason;
    Map<String, dynamic>? scrapItem;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Scrap'),
        scrollable: true,
        content: StatefulBuilder(
          builder: (dialogCtx, setSheetState) => Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: woCtl,
                  decoration: const InputDecoration(
                    labelText: 'Work Order ID *',
                    hintText: 'Paste UUID',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                KSpacing.vGapSm,
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final picked = await showItemPicker(dialogCtx);
                    if (picked != null) setSheetState(() => scrapItem = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Item *',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(scrapItem?['name']?.toString() ?? 'Tap to select'),
                  ),
                ),
                KSpacing.vGapSm,
                TextFormField(
                  controller: qtyCtl,
                  decoration: const InputDecoration(labelText: 'Scrap Qty *'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Enter a number';
                    if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                    return null;
                  },
                ),
                KSpacing.vGapSm,
                KEntityPickerField(
                  label: 'Reason Code *',
                  icon: Icons.label_outline,
                  value: reason,
                  search: _searchReasonCodes,
                  onChanged: (o) => setSheetState(() => reason = o),
                ),
                KSpacing.vGapSm,
                TextFormField(
                  controller: jobCardCtl,
                  decoration: const InputDecoration(
                    labelText: 'Job Card ID (optional)',
                    hintText: 'Paste UUID',
                  ),
                ),
                KSpacing.vGapSm,
                TextFormField(
                  controller: notesCtl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            label: 'Submit',
            onPressed: () {
              final ok = formKey.currentState!.validate();
              if (ok && scrapItem != null && reason != null) {
                Navigator.pop(ctx, true);
              } else if (scrapItem == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Select an item')),
                );
              } else if (reason == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Select a reason code')),
                );
              }
            },
          ),
        ],
      ),
    );

    if (submitted != true || !context.mounted) return;

    try {
      await ref.read(scrapRepositoryProvider).recordScrap(
            workOrderId: woCtl.text.trim(),
            itemId: scrapItem!['id'].toString(),
            scrapQty: double.parse(qtyCtl.text.trim()),
            reasonCodeId: reason!.id,
            jobCardId: jobCardCtl.text.trim(),
            notes: notesCtl.text.trim(),
          );
      ref.invalidate(scrapListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scrap recorded successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<List<EntityOption>> _searchReasonCodes(String query) async {
    final codes = await ref.read(scrapReasonCodesProvider.future);
    final q = query.toLowerCase();
    return codes
        .where((c) =>
            q.isEmpty ||
            (c['code']?.toString().toLowerCase().contains(q) ?? false) ||
            (c['description']?.toString().toLowerCase().contains(q) ?? false))
        .map((c) => EntityOption(
              id: c['id']?.toString() ?? '',
              label: c['code']?.toString() ?? '(no code)',
              subtitle: c['description']?.toString(),
              raw: c,
            ))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Add Reason Code bottom sheet
  // ---------------------------------------------------------------------------

  Future<void> _showAddReasonCodeSheet(BuildContext context) async {
    final codeCtl = TextEditingController();
    final descCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Reason Code', style: KTypography.h3),
              KSpacing.vGapMd,
              TextFormField(
                controller: codeCtl,
                decoration: const InputDecoration(
                  labelText: 'Code *',
                  hintText: 'e.g. BROKEN_PART',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              KSpacing.vGapSm,
              TextFormField(
                controller: descCtl,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Short description of the reason',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              KSpacing.vGapLg,
              KButton.primary(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(sheetCtx);
                  try {
                    await ref.read(scrapRepositoryProvider).createReasonCode(
                          code: codeCtl.text.trim().toUpperCase(),
                          description: descCtl.text.trim(),
                        );
                    ref.invalidate(scrapReasonCodesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reason code added'),
                          backgroundColor: KColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
                      );
                    }
                  }
                },
                label: 'Add Reason Code',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab: Scrap Records
// ---------------------------------------------------------------------------

class _ScrapRecordsTab extends ConsumerWidget {
  const _ScrapRecordsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scrapListProvider);

    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading scrap records...')),
      error: (e, _) => KErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(scrapListProvider),
      ),
      data: (records) {
        if (records.isEmpty) {
          return const KEmptyState(
            icon: Icons.delete_sweep_outlined,
            title: 'No scrap records',
            subtitle: 'Tap "Record Scrap" to log production waste.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(scrapListProvider),
          child: ListView.builder(
            padding: KSpacing.pagePadding,
            itemCount: records.length,
            itemBuilder: (ctx, i) => _ScrapCard(record: records[i]),
          ),
        );
      },
    );
  }
}

class _ScrapCard extends StatelessWidget {
  const _ScrapCard({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final workOrderId = _trunc(record['workOrderId']?.toString());
    final itemId = _trunc(record['itemId']?.toString());
    final scrapQty = record['scrapQty']?.toString() ?? '0';
    final scrapCost = (record['scrapCost'] as num?)?.toDouble();
    final reasonCodeId = _trunc(record['reasonCodeId']?.toString());
    final scrappedAt = _formatDate(record['scrappedAt']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: KColors.warning),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Row(
                      children: [
                        Text('WO: ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                        Text(
                          workOrderId,
                          style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    scrappedAt,
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Field(label: 'Item', value: itemId),
                  _Field(label: 'Qty', value: scrapQty),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Cost: ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                      if (scrapCost != null)
                        KMoney(scrapCost, size: KMoneySize.small)
                      else
                        Text('—', style: KTypography.bodySmall),
                    ],
                  ),
                  _Field(label: 'Reason', value: reasonCodeId),
                ],
              ),
              if (record['notes'] != null &&
                  (record['notes'] as String).isNotEmpty) ...[
                KSpacing.vGapXs,
                Text(
                  record['notes'].toString(),
                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _trunc(String? id) {
    if (id == null || id.isEmpty) return '—';
    return id.length > 8 ? '${id.substring(0, 8)}…' : id;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ---------------------------------------------------------------------------
// Tab: Reason Codes
// ---------------------------------------------------------------------------

class _ReasonCodesTab extends ConsumerWidget {
  const _ReasonCodesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scrapReasonCodesProvider);

    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading reason codes...')),
      error: (e, _) => KErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(scrapReasonCodesProvider),
      ),
      data: (codes) {
        if (codes.isEmpty) {
          return const KEmptyState(
            icon: Icons.label_outline,
            title: 'No reason codes',
            subtitle: 'Tap "Add Reason Code" to create the first one.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(scrapReasonCodesProvider),
          child: ListView.builder(
            padding: KSpacing.pagePadding,
            itemCount: codes.length,
            itemBuilder: (ctx, i) => _ReasonCodeCard(code: codes[i]),
          ),
        );
      },
    );
  }
}

class _ReasonCodeCard extends StatelessWidget {
  const _ReasonCodeCard({required this.code});
  final Map<String, dynamic> code;

  @override
  Widget build(BuildContext context) {
    final codeStr = code['code']?.toString() ?? '';
    final description = code['description']?.toString() ?? '';
    final isActive = code['isActive'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.label_outline, size: 20, color: KColors.primary),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      codeStr,
                      style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    if (description.isNotEmpty) ...[
                      KSpacing.vGapXxs,
                      Text(
                        description,
                        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              KSpacing.hGapSm,
              KStatusChip(
                status: isActive ? 'ACTIVE' : 'INACTIVE',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: KTypography.bodySmall,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: KColors.textSecondary),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600, color: KColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
