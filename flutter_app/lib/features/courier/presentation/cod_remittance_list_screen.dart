import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/courier_repository.dart';

/// COD remittance ingest + reconcile. A remittance is the courier's payout —
/// gross collected, fees withheld, net to bank. Reconcile auto-posts payments
/// for matched AWBs, flags amount mismatches, and surfaces orphans to the AI Inbox.
class CodRemittanceListScreen extends ConsumerStatefulWidget {
  const CodRemittanceListScreen({super.key});

  @override
  ConsumerState<CodRemittanceListScreen> createState() =>
      _CodRemittanceListScreenState();
}

class _CodRemittanceListScreenState extends ConsumerState<CodRemittanceListScreen> {
  List<dynamic>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(courierRepositoryProvider).listRemittances();
      if (mounted) setState(() { _items = r; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Load failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  Future<void> _reconcile(String id, String number) async {
    try {
      final r = await ref
          .read(courierRepositoryProvider)
          .reconcileRemittance(id);
      if (!mounted) return;
      final matched = r['matched'] ?? 0;
      final mismatch = r['amountMismatch'] ?? 0;
      final orphan = r['orphan'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '$number reconciled: $matched matched, $mismatch mismatch, $orphan orphan'),
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Reconcile failed: ${e.toString().replaceAll('Exception: ', '')}'),
      ));
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => const _CreateCodRemittanceScreen()));
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COD Remittances'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New remittance'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  KCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reconcile COD payouts from your couriers',
                            style: KTypography.labelLarge),
                        KSpacing.vGapXs,
                        Text(
                          'Upload or enter the payout: matched parcels auto-settle '
                          'the invoices, amount differences are flagged for review, '
                          'and unknown AWBs land in your AI Inbox.',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,
                  ...(_items ?? const []).map(_remittanceTile),
                  if ((_items ?? const []).isEmpty)
                    KCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No remittances yet. Tap "New remittance" to record one.',
                          textAlign: TextAlign.center,
                          style: KTypography.bodyMedium
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _remittanceTile(dynamic r) {
    final status = r['status'] as String? ?? '';
    final variance = (r['variance'] as num?)?.toDouble() ?? 0;
    final isReconciled = status == 'RECONCILED';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r['remittanceNumber']} · ${r['courierPartner']}',
                    style: KTypography.labelLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isReconciled ? KColors.success : KColors.warning)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(status,
                      style: KTypography.bodySmall.copyWith(
                          color: isReconciled
                              ? KColors.success
                              : KColors.warning)),
                ),
              ],
            ),
            KSpacing.vGapXs,
            Text('Date: ${r['remittanceDate']}',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary)),
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _money('Gross', r['grossCollected'], KColors.textPrimary),
                _money('Fees', r['totalFees'], KColors.error),
                _money('Net', r['netRemitted'], KColors.success),
                _money('Variance', r['variance'],
                    variance.abs() < 0.01 ? KColors.success : KColors.warning),
              ],
            ),
            if (!isReconciled) ...[
              KSpacing.vGapSm,
              Align(
                alignment: Alignment.centerRight,
                child: KButton(
                  label: 'Reconcile',
                  icon: Icons.task_alt,
                  onPressed: () => _reconcile(
                      r['id']?.toString() ?? '',
                      r['remittanceNumber']?.toString() ?? 'remittance'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _money(String label, dynamic value, Color color) {
    final v = (value as num?)?.toDouble() ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: KTypography.bodySmall
                .copyWith(color: KColors.textSecondary)),
        Text(CurrencyFormatter.formatIndian(v),
            style: KTypography.bodyMedium.copyWith(color: color)),
      ],
    );
  }
}

/// Quick-entry form: a few header fields + N AWB lines.
class _CreateCodRemittanceScreen extends ConsumerStatefulWidget {
  const _CreateCodRemittanceScreen();

  @override
  ConsumerState<_CreateCodRemittanceScreen> createState() =>
      _CreateCodRemittanceScreenState();
}

class _CreateCodRemittanceScreenState
    extends ConsumerState<_CreateCodRemittanceScreen> {
  String _partner = 'DELHIVERY';
  final _bank = TextEditingController();
  final _utr = TextEditingController();
  final _net = TextEditingController();
  final DateTime _date = DateTime.now();
  final List<_LineRow> _lines = [_LineRow()];
  bool _saving = false;

  @override
  void dispose() {
    _bank.dispose();
    _utr.dispose();
    _net.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    final lines = _lines
        .where((l) => l.awb.text.trim().isNotEmpty)
        .map((l) => {
              'awbNumber': l.awb.text.trim(),
              'codAmount':
                  double.tryParse(l.cod.text.trim()) ?? 0,
              'codFee': double.tryParse(l.fee.text.trim()) ?? 0,
            })
        .toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add at least one AWB line')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(courierRepositoryProvider).createRemittance({
        'courierPartner': _partner,
        'remittanceDate':
            '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
        'bankAccount': _bank.text.trim(),
        'utr': _utr.text.trim(),
        'netRemitted': double.tryParse(_net.text.trim()) ?? 0,
        'lines': lines,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Save failed: ${e.toString().replaceAll('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New COD Remittance')),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Courier', style: KTypography.labelLarge),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  initialValue: _partner,
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    'BLUEDART',
                    'DELHIVERY',
                    'INDIA_POST',
                    'DTDC',
                    'SHIPROCKET',
                    'OTHER',
                  ]
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _partner = v ?? _partner),
                ),
                KSpacing.vGapMd,
                KTextField(
                  label: 'Bank account (e.g. HDFC-1234)',
                  controller: _bank,
                ),
                KSpacing.vGapSm,
                KTextField(
                    label: 'UTR / payout reference', controller: _utr),
                KSpacing.vGapSm,
                KTextField(
                    label: 'Net remitted to bank',
                    controller: _net,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true)),
              ],
            ),
          ),
          KSpacing.vGapMd,
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text('AWBs in this payout',
                            style: KTypography.labelLarge)),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _lines.add(_LineRow())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                ..._lines.asMap().entries.map((e) {
                  final i = e.key;
                  final l = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 3,
                            child: KTextField(
                                label: 'AWB', controller: l.awb)),
                        KSpacing.hGapSm,
                        Expanded(
                            flex: 2,
                            child: KTextField(
                                label: 'COD',
                                controller: l.cod,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true))),
                        KSpacing.hGapSm,
                        Expanded(
                            flex: 2,
                            child: KTextField(
                                label: 'Fee',
                                controller: l.fee,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true))),
                        if (_lines.length > 1)
                          IconButton(
                            onPressed: () =>
                                setState(() => _lines.removeAt(i)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          KSpacing.vGapLg,
          KButton(
            label: _saving ? 'Saving…' : 'Save remittance',
            icon: Icons.save,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _LineRow {
  final TextEditingController awb = TextEditingController();
  final TextEditingController cod = TextEditingController();
  final TextEditingController fee = TextEditingController();
  void dispose() {
    awb.dispose();
    cod.dispose();
    fee.dispose();
  }
}
