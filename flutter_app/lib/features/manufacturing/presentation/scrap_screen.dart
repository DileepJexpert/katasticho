import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
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
    final theme = Theme.of(context);
    final isReasonTab = _tabs.index == 1;

    return Scaffold(
      body: Column(
        children: [
          const KListPageHeader(
            title: 'Production Scrap',
            subtitle: 'Record and manage scrap/waste from production runs.',
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
              onPressed: () => _showAddReasonCodeSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Reason Code'),
              tooltip: 'Add Reason Code (N)',
            )
          : FloatingActionButton.extended(
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
    final itemCtl = TextEditingController();
    final qtyCtl = TextEditingController();
    final reasonCtl = TextEditingController();
    final jobCardCtl = TextEditingController();
    final notesCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Scrap'),
        scrollable: true,
        content: Form(
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
              const SizedBox(height: 12),
              TextFormField(
                controller: itemCtl,
                decoration: const InputDecoration(
                  labelText: 'Item ID *',
                  hintText: 'Paste UUID',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtl,
                decoration: const InputDecoration(
                  labelText: 'Reason Code ID *',
                  hintText: 'Paste UUID',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: jobCardCtl,
                decoration: const InputDecoration(
                  labelText: 'Job Card ID (optional)',
                  hintText: 'Paste UUID',
                ),
              ),
              const SizedBox(height: 12),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (submitted != true || !context.mounted) return;

    try {
      await ref.read(scrapRepositoryProvider).recordScrap(
            workOrderId: woCtl.text.trim(),
            itemId: itemCtl.text.trim(),
            scrapQty: double.parse(qtyCtl.text.trim()),
            reasonCodeId: reasonCtl.text.trim(),
            jobCardId: jobCardCtl.text.trim(),
            notes: notesCtl.text.trim(),
          );
      ref.invalidate(scrapListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scrap recorded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
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
              Text(
                'Add Reason Code',
                style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtl,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Short description of the reason',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
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
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
                child: const Text('Add Reason Code'),
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
            padding: const EdgeInsets.all(16),
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
    final theme = Theme.of(context);

    final workOrderId = _trunc(record['workOrderId']?.toString());
    final itemId = _trunc(record['itemId']?.toString());
    final scrapQty = record['scrapQty']?.toString() ?? '0';
    final scrapCost = record['scrapCost'];
    final reasonCodeId = _trunc(record['reasonCodeId']?.toString());
    final scrappedAt = _formatDate(record['scrappedAt']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'WO: $workOrderId',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    scrappedAt,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Field(label: 'Item', value: itemId),
                  _Field(label: 'Qty', value: scrapQty),
                  _Field(
                    label: 'Cost',
                    value: scrapCost != null ? '₹$scrapCost' : '—',
                  ),
                  _Field(label: 'Reason', value: reasonCodeId),
                ],
              ),
              if (record['notes'] != null &&
                  (record['notes'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  record['notes'].toString(),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[600]),
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

  /// Show first 8 chars of a UUID followed by '…'
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
            padding: const EdgeInsets.all(16),
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
    final theme = Theme.of(context);
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
              const Icon(Icons.label_outline, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      codeStr,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? Colors.green[800] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: isActive
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.15),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
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
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: Colors.grey),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
