import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/forex_revaluation_repository.dart';

final _forexRunsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(forexRevaluationRepositoryProvider).runs();
});

/// Period-end forex revaluation (H8). Restates open foreign-currency AR/AP to
/// the closing rate as of a date, previews the unrealized gain/loss, then posts
/// a consolidated journal plus its next-day reversal.
class ForexRevaluationScreen extends ConsumerStatefulWidget {
  const ForexRevaluationScreen({super.key});

  @override
  ConsumerState<ForexRevaluationScreen> createState() =>
      _ForexRevaluationScreenState();
}

class _ForexRevaluationScreenState
    extends ConsumerState<ForexRevaluationScreen> {
  DateTime _asOfDate = DateTime.now();
  Map<String, dynamic>? _preview;
  bool _busy = false;

  String get _asOfIso => _asOfDate.toIso8601String().split('T').first;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _asOfDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _asOfDate = picked;
        _preview = null; // stale once the date changes
      });
    }
  }

  Future<void> _runPreview() async {
    setState(() => _busy = true);
    try {
      final res =
          await ref.read(forexRevaluationRepositoryProvider).preview(_asOfIso);
      setState(() => _preview = res);
    } catch (e) {
      _toast(ApiErrorParser.message(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post revaluation?'),
        content: Text(
            'Posts a consolidated revaluation journal as of $_asOfIso plus an '
            'auto-reversing entry on the next day. This affects the ledger.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Post')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final res =
          await ref.read(forexRevaluationRepositoryProvider).run(_asOfIso);
      final id = res['revalJournalEntryId'];
      _toast(id == null
          ? 'Nothing to revalue — no journal posted.'
          : 'Revaluation posted.');
      setState(() => _preview = null);
      ref.invalidate(_forexRunsProvider);
    } catch (e) {
      _toast(ApiErrorParser.message(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: error ? KColors.error : null));
  }

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(_forexRunsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Forex Revaluation')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_forexRunsProvider),
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            _controlsCard(),
            if (_preview != null) ...[
              const SizedBox(height: KSpacing.md),
              _previewCard(_preview!),
            ],
            const SizedBox(height: KSpacing.lg),
            Text('Past runs', style: KTypography.titleSmall),
            const SizedBox(height: KSpacing.sm),
            runsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(KSpacing.lg),
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(ApiErrorParser.message(e)),
              data: (runs) => runs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Text('No revaluation runs yet',
                          style: KTypography.bodySmall.copyWith(
                              color: Theme.of(context).colorScheme.outline)),
                    )
                  : Column(
                      children: runs
                          .map((r) => _runTile(r as Map<String, dynamic>))
                          .toList()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 20),
                const SizedBox(width: KSpacing.sm),
                Text('As of date', style: KTypography.bodyMedium),
                const Spacer(),
                OutlinedButton(
                  onPressed: _busy ? null : _pickDate,
                  child: Text(_asOfIso),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _runPreview,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _post,
                    icon: const Icon(Icons.post_add_outlined),
                    label: const Text('Post'),
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: KSpacing.sm),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewCard(Map<String, dynamic> p) {
    final base = p['baseCurrency'] as String? ?? '';
    final count = (p['revaluedDocumentCount'] as num?)?.toInt() ?? 0;
    final lines = (p['lines'] as List?) ?? [];
    final warnings = (p['warnings'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Preview', style: KTypography.titleSmall),
                const SizedBox(width: KSpacing.sm),
                Text('$count document(s) · base $base',
                    style: KTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
            const Divider(height: KSpacing.lg),
            _amountRow('AR delta', p['arDelta']),
            _amountRow('AP delta', p['apDelta']),
            _amountRow('Net gain / (loss)', p['netGainLoss'], emphasise: true),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: KSpacing.sm),
              ...warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: Color(0xFFB45309)),
                        const SizedBox(width: KSpacing.xs),
                        Expanded(
                            child: Text(w.toString(),
                                style: KTypography.bodySmall.copyWith(
                                    color: const Color(0xFFB45309)))),
                      ],
                    ),
                  )),
            ],
            if (lines.isNotEmpty) ...[
              const SizedBox(height: KSpacing.sm),
              const Divider(height: KSpacing.md),
              ...lines.map((l) => _lineTile(l as Map<String, dynamic>)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, dynamic value, {bool emphasise = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: emphasise
                  ? KTypography.titleSmall
                  : KTypography.bodyMedium),
          KMoney((value as num?) ?? 0,
              colorBySign: true,
              size: emphasise ? KMoneySize.medium : KMoneySize.small),
        ],
      ),
    );
  }

  Widget _lineTile(Map<String, dynamic> l) {
    final side = l['side'] as String? ?? '';
    final currency = l['currency'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          KStatusChip(status: side, dense: true),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l['documentNumber'] as String? ?? '—',
                    style: KTypography.bodySmall),
                Text(
                    '${l['balanceDue'] ?? ''} $currency  @ '
                    '${l['bookRate'] ?? ''}→${l['closingRate'] ?? ''}',
                    style: KTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          KMoney((l['delta'] as num?) ?? 0, colorBySign: true),
        ],
      ),
    );
  }

  Widget _runTile(Map<String, dynamic> r) {
    final reversed = r['reversalJournalEntryId'] != null;
    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.currency_exchange_outlined),
        title: Text(r['asOfDate']?.toString() ?? '—',
            style: KTypography.titleSmall),
        subtitle: Text(
            '${(r['revaluedDocumentCount'] as num?)?.toInt() ?? 0} document(s)'
            '${reversed ? ' · auto-reversed next day' : ''}'),
        trailing: KMoney((r['netGainLoss'] as num?) ?? 0, colorBySign: true),
      ),
    );
  }
}
