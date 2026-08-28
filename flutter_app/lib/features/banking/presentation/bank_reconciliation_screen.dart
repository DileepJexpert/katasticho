import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/bank_reconciliation_repository.dart';

class BankReconciliationScreen extends ConsumerStatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  ConsumerState<BankReconciliationScreen> createState() =>
      _BankReconciliationScreenState();
}

class _BankReconciliationScreenState
    extends ConsumerState<BankReconciliationScreen> {
  static const _filters = [
    'ALL',
    'UNMATCHED',
    'SUGGESTED',
    'MATCHED',
    'IGNORED'
  ];

  final TextEditingController _csvController = TextEditingController();
  String _selectedStatus = 'ALL';
  bool _isLoading = true;
  bool _isImporting = false;
  String? _error;
  List<Map<String, dynamic>> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _csvController.text =
        'date,amount,direction,narration,utr,payerName,payerVpa\n'
        '2026-05-14,1200,CREDIT,"Payment for INV-2026-000011",UTR123,Rajesh Traders,rajesh@upi';
    _loadTransactions();
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(bankReconciliationRepositoryProvider).listTransactions(
                status: _selectedStatus,
              );
      final data =
          Map<String, dynamic>.from((response['data'] as Map?) ?? const {});
      final content = (data['content'] as List?) ?? const [];
      if (!mounted) return;
      setState(() {
        _transactions = content
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importCsv() async {
    final text = _csvController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isImporting = true);
    try {
      final response =
          await ref.read(bankReconciliationRepositoryProvider).importCsv(text);
      final data =
          Map<String, dynamic>.from((response['data'] as Map?) ?? const {});
      final imported = (data['imported'] as num?)?.toInt() ?? 0;
      final skipped = (data['skipped'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Imported $imported transaction(s), skipped $skipped.')),
      );
      await _loadTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// Upload the bank's own statement export (.csv/.xlsx) — no reformatting
  /// needed; the backend finds the header and falls back to AI if it can't.
  Future<void> _importStatementFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls', 'txt'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !mounted) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _isImporting = true);
    try {
      final response = await ref
          .read(bankReconciliationRepositoryProvider)
          .importFile(bytes.toList(), file.name);
      final data =
          Map<String, dynamic>.from((response['data'] as Map?) ?? const {});
      final imported = (data['imported'] as num?)?.toInt() ?? 0;
      final skipped = (data['skipped'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Imported $imported transaction(s), skipped $skipped.')),
      );
      await _loadTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _acceptMatch(String matchId) async {
    try {
      await ref.read(bankReconciliationRepositoryProvider).acceptMatch(matchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match accepted and payment recorded.')),
      );
      await _loadTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accept failed: $e')),
      );
    }
  }

  Future<void> _rejectMatch(String matchId) async {
    try {
      await ref.read(bankReconciliationRepositoryProvider).rejectMatch(matchId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suggested match rejected.')),
      );
      await _loadTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e')),
      );
    }
  }

  Future<void> _rerunMatch(String transactionId) async {
    try {
      await ref
          .read(bankReconciliationRepositoryProvider)
          .rerunMatch(transactionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matching rerun completed.')),
      );
      await _loadTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rerun failed: $e')),
      );
    }
  }

  Future<void> _ignoreTransaction(String transactionId) async {
    try {
      await ref
          .read(bankReconciliationRepositoryProvider)
          .ignoreTransaction(transactionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction ignored.')),
      );
      await _loadTransactions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ignore failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _buildSummary(_transactions);
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Reconciliation')),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            _SummaryStrip(summary: summary),
            KSpacing.vGapMd,
            _ImportCard(
              controller: _csvController,
              isImporting: _isImporting,
              onImport: _importCsv,
              onUploadFile: _importStatementFile,
            ),
            KSpacing.vGapMd,
            _FilterBar(
              selected: _selectedStatus,
              filters: _filters,
              onSelected: (value) {
                if (_selectedStatus == value) return;
                setState(() => _selectedStatus = value);
                _loadTransactions();
              },
            ),
            KSpacing.vGapMd,
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              KErrorBanner(message: _error!)
            else if (_transactions.isEmpty)
              const SizedBox(
                height: 280,
                child: KEmptyState(
                  icon: Icons.account_balance_outlined,
                  title: 'No bank transactions yet',
                  subtitle:
                      'Paste a CSV statement to import transactions and start matching them to invoices.',
                ),
              )
            else
              ..._transactions.map(
                (tx) => Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: _TransactionCard(
                    tx: tx,
                    onAcceptMatch: _acceptMatch,
                    onRejectMatch: _rejectMatch,
                    onRerun: _rerunMatch,
                    onIgnore: _ignoreTransaction,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Map<String, int> _buildSummary(List<Map<String, dynamic>> transactions) {
  int unmatched = 0;
  int suggested = 0;
  int matched = 0;
  int ignored = 0;

  for (final tx in transactions) {
    switch ((tx['status']?.toString() ?? '').toUpperCase()) {
      case 'MATCHED':
        matched++;
        break;
      case 'SUGGESTED':
        suggested++;
        break;
      case 'IGNORED':
        ignored++;
        break;
      default:
        unmatched++;
    }
  }

  return {
    'UNMATCHED': unmatched,
    'SUGGESTED': suggested,
    'MATCHED': matched,
    'IGNORED': ignored,
  };
}

class _SummaryStrip extends StatelessWidget {
  final Map<String, int> summary;

  const _SummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Unmatched', summary['UNMATCHED'] ?? 0, KColors.warning),
      ('Suggested', summary['SUGGESTED'] ?? 0, KColors.primary),
      ('Matched', summary['MATCHED'] ?? 0, KColors.success),
      ('Ignored', summary['IGNORED'] ?? 0, KColors.textHint),
    ];

    return KCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final children = items
              .map((item) => Expanded(
                    child: _MetricTile(
                      label: item.$1,
                      value: item.$2.toString(),
                      color: item.$3,
                    ),
                  ))
              .toList();
          if (wide) {
            return Row(
              children: [
                children[0],
                KSpacing.hGapSm,
                children[1],
                KSpacing.hGapSm,
                children[2],
                KSpacing.hGapSm,
                children[3],
              ],
            );
          }
          return Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: items
                .map((item) => SizedBox(
                      width: (constraints.maxWidth - KSpacing.sm) / 2,
                      child: _MetricTile(
                        label: item.$1,
                        value: item.$2.toString(),
                        color: item.$3,
                      ),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: KSpacing.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: KTypography.h2.copyWith(color: color)),
          KSpacing.vGapXs,
          Text(
            label,
            style: KTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isImporting;
  final VoidCallback onImport;
  final VoidCallback onUploadFile;

  const _ImportCard({
    required this.controller,
    required this.isImporting,
    required this.onImport,
    required this.onUploadFile,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Import bank / UPI statement',
      subtitle:
          'Upload your bank\'s statement export as-is (CSV/Excel) — the header is '
          'detected automatically, with AI fallback for odd formats. Or paste rows below.',
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isImporting ? null : onUploadFile,
              icon: isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(isImporting
                  ? 'Importing...'
                  : 'Upload statement file (.csv / .xlsx)'),
            ),
          ),
          KSpacing.vGapMd,
          TextField(
            controller: controller,
            minLines: 5,
            maxLines: 9,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText:
                  'Or paste statement rows here (any bank format works)',
            ),
          ),
          KSpacing.vGapMd,
          Row(
            children: [
              Expanded(
                child: Text(
                  'Credits match outstanding invoices; debits match open vendor bills. '
                  'Accepting a match records the payment automatically.',
                  style: KTypography.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              KSpacing.hGapSm,
              OutlinedButton.icon(
                onPressed: isImporting ? null : onImport,
                icon: const Icon(Icons.content_paste_go, size: 18),
                label: const Text('Import pasted'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final List<String> filters;
  final ValueChanged<String> onSelected;

  const _FilterBar({
    required this.selected,
    required this.filters,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters
            .map(
              (filter) => Padding(
                padding: const EdgeInsets.only(right: KSpacing.sm),
                child: ChoiceChip(
                  selected: selected == filter,
                  label: Text(filter.replaceAll('_', ' ')),
                  onSelected: (_) => onSelected(filter),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final ValueChanged<String> onAcceptMatch;
  final ValueChanged<String> onRejectMatch;
  final ValueChanged<String> onRerun;
  final ValueChanged<String> onIgnore;

  const _TransactionCard({
    required this.tx,
    required this.onAcceptMatch,
    required this.onRejectMatch,
    required this.onRerun,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final matches = ((tx['suggestedMatches'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final direction = tx['direction']?.toString() ?? 'CREDIT';
    final amountColor = direction == 'DEBIT' ? KColors.error : KColors.success;
    final createdAt = DateTime.tryParse(tx['createdAt']?.toString() ?? '');

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        KMoney(
                          amount,
                          size: KMoneySize.medium,
                          style: TextStyle(color: amountColor),
                        ),
                        KStatusChip(
                          status: tx['status']?.toString() ?? 'UNMATCHED',
                          label: (tx['status']?.toString() ?? 'UNMATCHED')
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                        ),
                        _DirectionPill(direction: direction),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(
                      tx['narration']?.toString() ?? 'No narration',
                      style: KTypography.bodyMedium,
                    ),
                    KSpacing.vGapXs,
                    Text.rich(
                      TextSpan(
                        style: KTypography.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          if (tx['utr']?.toString().isNotEmpty == true) ...[
                            const TextSpan(text: 'UTR: '),
                            TextSpan(text: tx['utr']?.toString(), style: KTypography.mono(fontSize: 12)),
                          ],
                          if (tx['payerName']?.toString().isNotEmpty == true) ...[
                            if (tx['utr']?.toString().isNotEmpty == true) const TextSpan(text: ' • '),
                            const TextSpan(text: 'Payer: '),
                            TextSpan(text: tx['payerName']?.toString()),
                          ],
                          if (tx['payerVpa']?.toString().isNotEmpty == true) ...[
                            if (tx['utr']?.toString().isNotEmpty == true || tx['payerName']?.toString().isNotEmpty == true) const TextSpan(text: ' • '),
                            const TextSpan(text: 'VPA: '),
                            TextSpan(text: tx['payerVpa']?.toString(), style: KTypography.mono(fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (createdAt != null)
                Text(
                  DateFormat('dd MMM').format(createdAt.toLocal()),
                  style:
                      KTypography.labelSmall.copyWith(color: KColors.textHint),
                ),
            ],
          ),
          KSpacing.vGapMd,
          if (matches.isEmpty)
            Text(
              'No suggested matches yet.',
              style: KTypography.bodySmall.copyWith(color: KColors.textHint),
            )
          else
            Column(
              children: matches
                  .map(
                    (match) => Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.sm),
                      child: Container(
                        padding: const EdgeInsets.all(KSpacing.sm),
                        decoration: BoxDecoration(
                          color: KColors.primary.withValues(alpha: 0.05),
                          borderRadius: KSpacing.borderRadiusSm,
                          border: Border.all(
                            color: KColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: match['matchType'] == 'BILL' ? 'Bill ' : ''),
                                        TextSpan(
                                          text: match['documentNumber'] ?? match['invoiceNumber'] ?? 'Unknown document',
                                          style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        TextSpan(text: ' • ${match['contactName'] ?? 'Unknown contact'}'),
                                      ],
                                    ),
                                    style: KTypography.labelLarge,
                                  ),
                                  KSpacing.vGapXs,
                                  Row(
                                    children: [
                                      Text(
                                        'Confidence ${(double.tryParse(match['confidence']?.toString() ?? '0') ?? 0) * 100 ~/ 1}% • Match ',
                                        style: KTypography.bodySmall.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      KMoney(
                                        (match['matchedAmount'] as num?)?.toDouble() ?? 0,
                                        size: KMoneySize.small,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if ((match['matchStatus']?.toString() ?? '') ==
                                'SUGGESTED') ...[
                              TextButton(
                                onPressed: () =>
                                    onRejectMatch(match['id'].toString()),
                                child: const Text('Reject'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    onAcceptMatch(match['id'].toString()),
                                child: const Text('Accept'),
                              ),
                            ] else
                              KStatusChip(
                                status: match['matchStatus']?.toString() ??
                                    'SUGGESTED',
                                label: (match['matchStatus']?.toString() ??
                                        'SUGGESTED')
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          KSpacing.vGapSm,
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => onRerun(tx['id'].toString()),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Rerun Match'),
              ),
              KSpacing.hGapSm,
              TextButton.icon(
                onPressed: () => onIgnore(tx['id'].toString()),
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('Ignore'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectionPill extends StatelessWidget {
  final String direction;

  const _DirectionPill({required this.direction});

  @override
  Widget build(BuildContext context) {
    final isCredit = direction.toUpperCase() == 'CREDIT';
    final color = isCredit ? KColors.success : KColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        direction.toUpperCase(),
        style: KTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
