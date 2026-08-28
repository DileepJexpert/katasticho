import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/credit_reminder_repository.dart';
import '../../reports/data/report_repository.dart';

enum _SortMode { amount, age }

enum _FilterMode { all, overdue, risk }

class CreditLedgerScreen extends ConsumerStatefulWidget {
  const CreditLedgerScreen({super.key});

  @override
  ConsumerState<CreditLedgerScreen> createState() => _CreditLedgerScreenState();
}

class _CreditLedgerScreenState extends ConsumerState<CreditLedgerScreen> {
  Map<String, dynamic>? _report;
  Map<String, Map<String, dynamic>> _riskByContactId = {};
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.amount;
  _FilterMode _filterMode = _FilterMode.all;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(reportRepositoryProvider);
      final data = await repo.getAgeingReport();
      final riskRepo = ref.read(creditReminderRepositoryProvider);
      final riskResponse = await riskRepo.getCustomerRisk();
      final riskRaw = riskResponse['data'];
      final riskList = riskRaw is List ? riskRaw : <dynamic>[];
      final riskByContactId = <String, Map<String, dynamic>>{};
      for (final entry in riskList) {
        if (entry is Map<String, dynamic>) {
          final contactId = entry['contactId']?.toString();
          if (contactId != null && contactId.isNotEmpty) {
            riskByContactId[contactId] = entry;
          }
        }
      }
      setState(() {
        _report = (data['data'] ?? data) as Map<String, dynamic>;
        _riskByContactId = riskByContactId;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load credit ledger');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredContacts() {
    final contacts =
        (_report?['contacts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    var filtered = contacts.where((c) {
      final total = (c['totalOutstanding'] as num?)?.toDouble() ?? 0;
      if (total <= 0) return false;
      if (_filterMode == _FilterMode.overdue) {
        final current = (c['current'] as num?)?.toDouble() ?? 0;
        return total - current > 0;
      }
      if (_filterMode == _FilterMode.risk) {
        final contactId = c['contactId']?.toString() ?? '';
        final risk = _riskByContactId[contactId];
        final riskLevel = risk?['riskLevel']?.toString() ?? 'OK';
        return riskLevel != 'OK' && riskLevel != 'WATCH';
      }
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final name = (c['contactName'] as String? ?? '').toLowerCase();
        return name.contains(q);
      }).toList();
    }

    filtered.sort((a, b) {
      if (_sortMode == _SortMode.amount) {
        final aAmt = (a['totalOutstanding'] as num?)?.toDouble() ?? 0;
        final bAmt = (b['totalOutstanding'] as num?)?.toDouble() ?? 0;
        return bAmt.compareTo(aAmt);
      } else {
        final aAge = _maxDaysOverdue(a);
        final bAge = _maxDaysOverdue(b);
        return bAge.compareTo(aAge);
      }
    });

    return filtered;
  }

  int _maxDaysOverdue(Map<String, dynamic> contact) {
    final invoices = (contact['invoices'] as List?) ?? [];
    int max = 0;
    for (final inv in invoices) {
      final days = (inv as Map<String, dynamic>)['daysOverdue'] as int? ??
          ((inv['daysOverdue'] as num?)?.toInt() ?? 0);
      if (days > max) max = days;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Credit Ledger',
            searchHint: 'Search customer...',
            onSearchChanged: (q) => setState(() => _searchQuery = q.trim()),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort, size: 20),
                tooltip: 'Sort & Filter',
                onSelected: (v) {
                  setState(() {
                    if (v == 'amount') _sortMode = _SortMode.amount;
                    if (v == 'age') _sortMode = _SortMode.age;
                    if (v == 'all') _filterMode = _FilterMode.all;
                    if (v == 'overdue') _filterMode = _FilterMode.overdue;
                    if (v == 'risk') _filterMode = _FilterMode.risk;
                  });
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'amount',
                    child: Row(
                      children: [
                        if (_sortMode == _SortMode.amount)
                          const Icon(Icons.check, size: 16),
                        if (_sortMode == _SortMode.amount)
                          const SizedBox(width: 8),
                        const Text('Sort: Highest amount'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'age',
                    child: Row(
                      children: [
                        if (_sortMode == _SortMode.age)
                          const Icon(Icons.check, size: 16),
                        if (_sortMode == _SortMode.age)
                          const SizedBox(width: 8),
                        const Text('Sort: Oldest first'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        if (_filterMode == _FilterMode.all)
                          const Icon(Icons.check, size: 16),
                        if (_filterMode == _FilterMode.all)
                          const SizedBox(width: 8),
                        const Text('All outstanding'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'overdue',
                    child: Row(
                      children: [
                        if (_filterMode == _FilterMode.overdue)
                          const Icon(Icons.check, size: 16),
                        if (_filterMode == _FilterMode.overdue)
                          const SizedBox(width: 8),
                        const Text('Overdue only'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'risk',
                    child: Row(
                      children: [
                        if (_filterMode == _FilterMode.risk)
                          const Icon(Icons.check, size: 16),
                        if (_filterMode == _FilterMode.risk)
                          const SizedBox(width: 8),
                        const Text('Risk only'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const KShimmerList();
    }
    if (_error != null) {
      return KErrorView(message: _error!, onRetry: _loadReport);
    }
    if (_report == null) {
      return const KEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No data',
      );
    }

    final contacts = _getFilteredContacts();
    final totalOutstanding =
        (_report!['totalOutstanding'] as num?)?.toDouble() ?? 0;

    if (contacts.isEmpty) {
      return KEmptyState(
        icon: Icons.celebration_outlined,
        title: _filterMode == _FilterMode.overdue
            ? 'No overdue balances'
            : _filterMode == _FilterMode.risk
                ? 'No risky customers'
                : 'No outstanding balances',
        subtitle: 'All customers are settled',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView.builder(
        padding: KSpacing.pagePadding,
        itemCount: contacts.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.md),
              child: KCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Outstanding',
                              style: KTypography.bodySmall),
                          KSpacing.vGapXs,
                          KMoney(
                            totalOutstanding,
                            size: KMoneySize.large,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${contacts.length}',
                            style: KTypography.h2
                                .copyWith(color: KColors.warning)),
                        Text('customers', style: KTypography.labelSmall),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          final contact = contacts[index - 1];
          final name = contact['contactName'] as String? ?? 'Unknown';
          final total = (contact['totalOutstanding'] as num?)?.toDouble() ?? 0;
          final maxAge = _maxDaysOverdue(contact);
          final contactId = contact['contactId']?.toString() ?? '';
          final risk = _riskByContactId[contactId];
          final riskLevel = risk?['riskLevel']?.toString() ?? 'OK';
          final utilization =
              (risk?['creditUtilizationPercent'] as num?)?.toDouble() ?? 0;
          final salesHold = risk?['salesHold'] == true;
          final latestFollowUp =
              risk?['latestFollowUp'] as Map<String, dynamic>?;

          return Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.sm),
            child: KCard(
              onTap: () => context.push(
                '/credit-ledger/$contactId',
                extra: contact,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        KColors.primaryLight.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: KTypography.labelLarge
                          .copyWith(color: KColors.primary),
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: KTypography.labelLarge),
                        KSpacing.vGapXs,
                        Text(
                          maxAge > 0
                              ? '$maxAge days overdue'
                              : _riskLabel(riskLevel, utilization, salesHold),
                          style: KTypography.bodySmall.copyWith(
                            color: _riskColor(riskLevel, maxAge),
                          ),
                        ),
                        if (latestFollowUp != null) ...[
                          KSpacing.vGapXs,
                          _FollowUpChip(followUp: latestFollowUp),
                        ],
                      ],
                    ),
                  ),
                  KMoney(
                    total,
                    size: KMoneySize.small,
                    style: TextStyle(
                      color: _riskColor(riskLevel, maxAge),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: KColors.textHint),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _riskLabel(String riskLevel, double utilization, bool salesHold) {
    if (salesHold || riskLevel == 'SALES_HOLD') return 'Sales hold';
    if (riskLevel == 'OVER_CREDIT') {
      return utilization > 0
          ? 'Over credit ${utilization.toStringAsFixed(0)}%'
          : 'Over credit';
    }
    if (riskLevel == 'OVERDUE') return 'Overdue';
    if (riskLevel == 'WATCH') return 'Watch';
    return 'Not yet due';
  }

  Color _riskColor(String riskLevel, int maxAge) {
    if (riskLevel == 'SALES_HOLD' || riskLevel == 'OVER_CREDIT') {
      return KColors.error;
    }
    if (riskLevel == 'OVERDUE' || maxAge > 60) return KColors.error;
    if (maxAge > 30 || riskLevel == 'WATCH') return KColors.warning;
    return KColors.textSecondary;
  }
}

class _FollowUpChip extends StatelessWidget {
  final Map<String, dynamic> followUp;

  const _FollowUpChip({required this.followUp});

  @override
  Widget build(BuildContext context) {
    final status = followUp['status']?.toString() ?? 'TO_CALL';
    final promiseDate = followUp['promiseToPayDate']?.toString();
    final label = promiseDate == null || promiseDate.isEmpty
        ? _label(status)
        : '${_label(status)} · PTP $promiseDate';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.event_note_outlined, size: 13, color: KColors.primary),
        KSpacing.hGapXs,
        Flexible(
          child: Text(
            label,
            style: KTypography.labelSmall.copyWith(color: KColors.primary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _label(String status) {
    return status
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
