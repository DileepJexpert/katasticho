import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Edit Log / audit trail viewer (MCA account-rules; TallyPrime Edit Log
/// parity). Read-only: every create / alter / delete / restore on books
/// documents and masters, with the field-level before → after diff.
///
/// Tokens used: KCard, KButton, KStatusChip, KColors.*, KSpacing.*,
/// KTypography.h4 / mono for values.
class EditLogScreen extends ConsumerStatefulWidget {
  const EditLogScreen({super.key});

  @override
  ConsumerState<EditLogScreen> createState() => _EditLogScreenState();
}

class _EditLogScreenState extends ConsumerState<EditLogScreen> {
  static const _entityTypes = [
    'INVOICE',
    'PAYMENT',
    'CREDIT_NOTE',
    'CUSTOMER_RECEIPT',
    'PURCHASE_BILL',
    'VENDOR_PAYMENT',
    'VENDOR_CREDIT',
    'EXPENSE',
    'JOURNAL_ENTRY',
    'ACCOUNT',
    'SALES_ORDER',
    'DELIVERY_CHALLAN',
    'PURCHASE_ORDER',
    'STOCK_RECEIPT',
    'POS_RECEIPT',
    'ESTIMATE',
    'CONTACT',
    'ITEM',
  ];
  static const _actions = ['CREATE', 'UPDATE', 'DELETE', 'RESTORE'];

  String? _entityType;
  String? _action;
  DateTimeRange? _range;

  bool _loading = false;
  String? _error;
  final List<Map<String, dynamic>> _entries = [];
  int _page = 0;
  bool _hasMore = false;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Map<String, dynamic> _queryParams(int page) {
    final df = DateFormat('yyyy-MM-dd');
    return {
      'page': page,
      'size': 50,
      if (_entityType != null) 'entityType': _entityType,
      if (_action != null) 'action': _action,
      if (_range != null) 'from': df.format(_range!.start),
      if (_range != null) 'to': df.format(_range!.end),
    };
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _entries.clear();
      _page = 0;
    });
    try {
      final api = ref.read(apiClientProvider);
      final df = DateFormat('yyyy-MM-dd');
      final results = await Future.wait([
        api.get(ApiConfig.auditEditLog, queryParameters: _queryParams(0)),
        api.get(ApiConfig.auditEditLogSummary, queryParameters: {
          if (_range != null) 'from': df.format(_range!.start),
          if (_range != null) 'to': df.format(_range!.end),
        }),
      ]);
      final pageData =
          (results[0].data['data'] as Map<String, dynamic>?) ?? const {};
      final summaryData =
          (results[1].data['data'] as Map<String, dynamic>?) ?? const {};
      if (!mounted) return;
      setState(() {
        _entries.addAll(((pageData['content'] as List?) ?? const [])
            .cast<Map<String, dynamic>>());
        _hasMore = pageData['last'] == false;
        _summary = summaryData;
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error =
            (e.response?.data is Map ? e.response?.data['message'] : null)
                    ?.toString() ??
                e.message ??
                'Failed to load the edit log');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    try {
      final response = await ref.read(apiClientProvider).get(
            ApiConfig.auditEditLog,
            queryParameters: _queryParams(_page + 1),
          );
      final pageData =
          (response.data['data'] as Map<String, dynamic>?) ?? const {};
      if (!mounted) return;
      setState(() {
        _page += 1;
        _entries.addAll(((pageData['content'] as List?) ?? const [])
            .cast<Map<String, dynamic>>());
        _hasMore = pageData['last'] == false;
      });
    } catch (_) {
      // keep what we have; the reload path surfaces errors
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 8),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail (Edit Log)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          Text(
            'Who created, altered or deleted books documents and masters — '
            'with the field-level before → after diff. Append-only; rows '
            'cannot be edited or switched off.',
            style:
                KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
          ),
          const SizedBox(height: KSpacing.lg),
          _buildFilters(),
          if (_summary != null) ...[
            const SizedBox(height: KSpacing.md),
            _buildSummaryCard(_summary!),
          ],
          const SizedBox(height: KSpacing.md),
          if (_error != null)
            KCard(
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: KColors.error),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: KColors.error)),
                  ),
                ],
              ),
            ),
          if (_loading && _entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(KSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_loading && _entries.isEmpty && _error == null)
            const KEmptyState(
              icon: Icons.history_rounded,
              title: 'No changes recorded yet',
              subtitle:
                  'Books activity will appear here as documents and masters '
                  'are created or altered.',
            ),
          ..._entries.map(_buildEntry),
          if (_hasMore) ...[
            const SizedBox(height: KSpacing.md),
            Center(
              child: KButton(
                label: _loading ? 'Loading…' : 'Load more',
                variant: KButtonVariant.secondary,
                onPressed: _loading ? null : _loadMore,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final df = DateFormat('d MMM yyyy');
    return KCard(
      child: Wrap(
        spacing: KSpacing.md,
        runSpacing: KSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String?>(
            value: _entityType,
            hint: const Text('All documents'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('All documents')),
              ..._entityTypes.map((t) => DropdownMenuItem<String?>(
                  value: t, child: Text(_pretty(t)))),
            ],
            onChanged: (v) {
              setState(() => _entityType = v);
              _reload();
            },
          ),
          DropdownButton<String?>(
            value: _action,
            hint: const Text('All actions'),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('All actions')),
              ..._actions.map((a) =>
                  DropdownMenuItem<String?>(value: a, child: Text(_pretty(a)))),
            ],
            onChanged: (v) {
              setState(() => _action = v);
              _reload();
            },
          ),
          KButton(
            label: _range == null
                ? 'Date range'
                : '${df.format(_range!.start)} – ${df.format(_range!.end)}',
            icon: Icons.date_range_outlined,
            variant: KButtonVariant.secondary,
            onPressed: _pickRange,
          ),
          if (_range != null || _entityType != null || _action != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _range = null;
                  _entityType = null;
                  _action = null;
                });
                _reload();
              },
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    final byAction =
        (summary['byAction'] as Map?)?.cast<String, dynamic>() ?? const {};
    final topUsers = ((summary['topUsers'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${summary['totalChanges'] ?? 0}',
                  style: KTypography.mono(size: 22)),
              const SizedBox(width: KSpacing.sm),
              Text('changes ${summary['from']} → ${summary['to']}',
                  style: const TextStyle(color: KColors.textSecondary)),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.xs,
            children: [
              ...byAction.entries
                  .map((e) => KStatusChip(status: '${e.key} ${e.value}')),
              if (topUsers.isNotEmpty)
                Text(
                  'Top: ${topUsers.take(3).map((u) => '${u['name'] ?? 'Unknown'} (${u['count']})').join(', ')}',
                  style: const TextStyle(
                      fontSize: 12, color: KColors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(Map<String, dynamic> entry) {
    final action = (entry['action'] ?? '') as String;
    final changes =
        (entry['fieldChanges'] as Map?)?.cast<String, dynamic>() ?? const {};
    final changedAt = DateTime.tryParse('${entry['changedAt']}')?.toLocal();
    final when = changedAt == null
        ? ''
        : DateFormat('d MMM yyyy, HH:mm').format(changedAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: KSpacing.sm),
            leading: Icon(_actionIcon(action), color: _actionColor(action)),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    entry['entityLabel']?.toString() ??
                        _pretty('${entry['entityType']}'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                KStatusChip(status: _pretty('${entry['entityType']}')),
              ],
            ),
            subtitle: Text(
              '${_pretty(action)} by ${entry['changedByName'] ?? 'System'} · $when',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              if (changes.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No field-level diff for this action.',
                      style: TextStyle(color: KColors.textSecondary)),
                )
              else
                ...changes.entries.map((change) {
                  final detail =
                      (change.value as Map?)?.cast<String, dynamic>() ??
                          const {};
                  return Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(change.key,
                              style: KTypography.mono(size: 12)),
                        ),
                        Expanded(
                          child: Text(
                            '${detail['from'] ?? '—'}  →  ${detail['to'] ?? '—'}',
                            style: KTypography.mono(size: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  static String _pretty(String raw) => raw
      .split('_')
      .map((w) =>
          w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  static IconData _actionIcon(String action) => switch (action) {
        'CREATE' => Icons.add_circle_outline,
        'DELETE' => Icons.delete_outline,
        'RESTORE' => Icons.restore,
        _ => Icons.edit_outlined,
      };

  static Color _actionColor(String action) => switch (action) {
        'CREATE' => KColors.success,
        'DELETE' => KColors.error,
        'RESTORE' => KColors.warning,
        _ => KColors.textSecondary,
      };
}
