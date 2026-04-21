import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../reports/data/report_repository.dart';

enum _SortMode { amount, age }
enum _FilterMode { all, overdue }

class CreditLedgerScreen extends ConsumerStatefulWidget {
  const CreditLedgerScreen({super.key});

  @override
  ConsumerState<CreditLedgerScreen> createState() => _CreditLedgerScreenState();
}

class _CreditLedgerScreenState extends ConsumerState<CreditLedgerScreen> {
  Map<String, dynamic>? _report;
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
      setState(() => _report = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = 'Failed to load credit ledger');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredContacts() {
    final contacts = (_report?['contacts'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    var filtered = contacts.where((c) {
      final total = (c['totalOutstanding'] as num?)?.toDouble() ?? 0;
      if (total <= 0) return false;
      if (_filterMode == _FilterMode.overdue) {
        final current = (c['current'] as num?)?.toDouble() ?? 0;
        return total - current > 0;
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
            onSearchChanged: (q) =>
                setState(() => _searchQuery = q.trim()),
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
                          Text(
                            CurrencyFormatter.formatIndian(totalOutstanding),
                            style: KTypography.amountLarge,
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
          final total =
              (contact['totalOutstanding'] as num?)?.toDouble() ?? 0;
          final maxAge = _maxDaysOverdue(contact);
          final contactId = contact['contactId']?.toString() ?? '';

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
                              : 'Not yet due',
                          style: KTypography.bodySmall.copyWith(
                            color: maxAge > 60
                                ? KColors.error
                                : maxAge > 30
                                    ? KColors.warning
                                    : KColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatIndian(total),
                    style: KTypography.amountSmall.copyWith(
                      color: maxAge > 60 ? KColors.error : KColors.warning,
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
}
