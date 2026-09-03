import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/bank_account_repository.dart';
import '../data/bank_auto_match_repository.dart';

class BankSmartAutoMatchScreen extends ConsumerStatefulWidget {
  const BankSmartAutoMatchScreen({super.key});

  @override
  ConsumerState<BankSmartAutoMatchScreen> createState() => _BankSmartAutoMatchScreenState();
}

class _BankSmartAutoMatchScreenState extends ConsumerState<BankSmartAutoMatchScreen> {
  String? _selectedBankAccountId;
  String _selectedStatus = 'PENDING';
  List<AutoMatchSuggestionDto> _suggestions = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBankAccounts();
  }

  Future<void> _loadBankAccounts() async {
    try {
      final accounts = await ref.read(bankAccountRepositoryProvider).list();
      if (accounts.isNotEmpty && mounted) {
        setState(() => _selectedBankAccountId = accounts.first['id'] as String);
        _loadSuggestions();
      }
    } catch (_) {}
  }

  Future<void> _loadSuggestions() async {
    if (_selectedBankAccountId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(bankAutoMatchRepositoryProvider);
      final list = await repo.listSuggestions(_selectedBankAccountId!, status: _selectedStatus);
      if (mounted) setState(() => _suggestions = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load match suggestions: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runSimulatedAutoMatch() async {
    if (_selectedBankAccountId == null) return;
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(bankAutoMatchRepositoryProvider);
      final sampleLines = [
        {
          'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T').first,
          'reference': 'CMS/2026/08912',
          'description': 'NEFT CR - APEX CHEMIST MUMBAI - INV 891',
          'amount': 3416.00,
          'credit': true,
        },
        {
          'date': DateTime.now().subtract(const Duration(days: 2)).toIso8601String().split('T').first,
          'reference': 'UPI/3882910023/KATASTICHO',
          'description': 'UPI PAY - RETAIL COUNTER SETTLEMENT',
          'amount': 1850.00,
          'credit': true,
        },
        {
          'date': DateTime.now().subtract(const Duration(days: 3)).toIso8601String().split('T').first,
          'reference': 'CHQ/882190',
          'description': 'CHQ CLG - GODREJ PROPERTIES RENT',
          'amount': 45000.00,
          'credit': false,
        },
      ];

      final created = await repo.runAutoMatch(_selectedBankAccountId!, sampleLines);
      if (mounted) {
        setState(() => _suggestions = created);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-match completed: ${created.length} statement entries analyzed!'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-match failed: $e'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _acceptSuggestion(String id) async {
    try {
      final repo = ref.read(bankAutoMatchRepositoryProvider);
      await repo.acceptSuggestion(id);
      _loadSuggestions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match accepted and reconciled!'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Accept failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _rejectSuggestion(String id) async {
    try {
      final repo = ref.read(bankAutoMatchRepositoryProvider);
      await repo.rejectSuggestion(id);
      _loadSuggestions();
    } catch (_) {}
  }

  Future<void> _bulkAccept() async {
    if (_selectedBankAccountId == null) return;
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(bankAutoMatchRepositoryProvider);
      final count = await repo.bulkAccept(_selectedBankAccountId!, minScore: 80);
      _loadSuggestions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reconciled $count high-confidence transactions!'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bulk accept failed: $e'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Auto-Match Reconciler'),
        actions: [
          KButton.secondary(
            label: 'Bulk Match (≥80%)',
            icon: Icons.done_all,
            onPressed: _isProcessing ? null : _bulkAccept,
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: _isProcessing ? 'Analyzing…' : 'Run Auto-Match',
            icon: Icons.auto_awesome,
            onPressed: _isProcessing ? null : _runSimulatedAutoMatch,
          ),
          KSpacing.hGapSm,
        ],
      ),
      body: Column(
        children: [
          // Filter & Account Header
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: KColors.primary, size: 20),
                KSpacing.hGapSm,
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['PENDING', 'ACCEPTED', 'REJECTED', 'ALL'].map((s) {
                        final isSel = _selectedStatus == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: isSel,
                            onSelected: (_) {
                              setState(() => _selectedStatus = s);
                              _loadSuggestions();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadSuggestions,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Main List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: KColors.error)),
                            KSpacing.vGapMd,
                            KButton.secondary(label: 'Retry', onPressed: _loadSuggestions),
                          ],
                        ),
                      )
                    : _suggestions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline, size: 64, color: KColors.textHint),
                                KSpacing.vGapMd,
                                Text('No pending auto-match suggestions', style: KTypography.h3),
                                KSpacing.vGapXs,
                                Text('Tap "Run Auto-Match" to match feed transactions against ledger journals.',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: KSpacing.pagePadding,
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) => KSpacing.vGapMd,
                            itemBuilder: (context, index) {
                              final item = _suggestions[index];
                              return _buildSuggestionCard(item);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(AutoMatchSuggestionDto item) {
    final score = item.confidenceScore;
    final scoreColor = score >= 85
        ? KColors.success
        : score >= 70
            ? KColors.warning
            : KColors.textSecondary;

    final isPending = item.status == 'PENDING';

    return KCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Score Badge
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: scoreColor.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Text(
                '$score%',
                style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          KSpacing.hGapMd,

          // Center: Statement vs Ledger Match Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.statementDescription ?? 'Bank Statement Transaction',
                      style: KTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${item.isCredit ? '+' : '-'} ${CurrencyFormatter.format(item.statementAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: item.isCredit ? KColors.success : KColors.error,
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text(item.statementDate, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                    if (item.statementReference != null) ...[
                      KSpacing.hGapMd,
                      Text('Ref: ${item.statementReference}',
                          style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                    ],
                  ],
                ),
                KSpacing.vGapXs,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: KColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link, size: 14, color: scoreColor),
                      KSpacing.hGapXs,
                      Text(item.matchReason, style: TextStyle(fontSize: 11, color: scoreColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          KSpacing.hGapMd,

          // Right: Action Buttons
          if (isPending) ...[
            Column(
              children: [
                KButton.primary(
                  label: 'Accept',
                  size: KButtonSize.small,
                  icon: Icons.check,
                  onPressed: () => _acceptSuggestion(item.id),
                ),
                KSpacing.vGapXs,
                KButton.secondary(
                  label: 'Reject',
                  size: KButtonSize.small,
                  icon: Icons.close,
                  onPressed: () => _rejectSuggestion(item.id),
                ),
              ],
            ),
          ] else ...[
            KStatusChip(status: item.status),
          ],
        ],
      ),
    );
  }
}