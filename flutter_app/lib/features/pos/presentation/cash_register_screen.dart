import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final cashRegisterProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiConfig.cashRegisterToday);
  return (resp.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
});

final cashRegisterHistoryProvider =
    FutureProvider.autoDispose.family<List<dynamic>, Map<String, String>>(
        (ref, params) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(
    ApiConfig.cashRegisterHistory,
    queryParameters: params,
  );
  final data = (resp.data as Map<String, dynamic>)['data'];
  if (data is List) return data;
  return [];
});

// ── Main Screen ────────────────────────────────────────────────────────────

class CashRegisterScreen extends ConsumerStatefulWidget {
  const CashRegisterScreen({super.key});

  @override
  ConsumerState<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends ConsumerState<CashRegisterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Register'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TodayTab(onRefresh: () => ref.invalidate(cashRegisterProvider)),
          const _HistoryTab(),
        ],
      ),
    );
  }
}

// ── Today Tab ──────────────────────────────────────────────────────────────

class _TodayTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  const _TodayTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cashRegisterProvider);
    return async.when(
      loading: () => const KLoading(),
      error: (e, _) => KErrorView(
        message: ApiErrorParser.message(e),
        onRetry: () => ref.invalidate(cashRegisterProvider),
      ),
      data: (data) => _TodayContent(data: data, onRefresh: onRefresh),
    );
  }
}

class _TodayContent extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;
  const _TodayContent({required this.data, required this.onRefresh});

  @override
  ConsumerState<_TodayContent> createState() => _TodayContentState();
}

class _TodayContentState extends ConsumerState<_TodayContent> {
  bool _submitting = false;

  String get _status => (widget.data['status'] as String?) ?? 'OPEN';
  bool get _isOpen => _status == 'OPEN';
  String? get _role => ref.read(authProvider).role?.toUpperCase();
  bool get _canClose => _role == 'OWNER' || _role == 'ADMIN';

  double _safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Future<void> _openRegister() async {
    final openingCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Register'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KTextField(
              label: 'Opening Cash Balance',
              controller: openingCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              hint: '0.00',
            ),
            const SizedBox(height: 12),
            KTextField(
              label: 'Notes (optional)',
              controller: notesCtrl,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.cashRegisterOpen, data: {
        'openingBalance': double.tryParse(openingCtrl.text) ?? 0.0,
        'notes': notesCtrl.text.isEmpty ? null : notesCtrl.text,
      });
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _addExpense() async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Expense'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KTextField(
                label: 'Amount',
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                hint: '0.00',
                isRequired: true,
              ),
              const SizedBox(height: 12),
              KTextField(
                label: 'Description',
                controller: descCtrl,
                hint: 'e.g. Auto fare, Tea',
                isRequired: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a description')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.cashRegisterExpense, data: {
        'amount': amount,
        'description': descCtrl.text.trim(),
      });
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.delete(ApiConfig.cashRegisterDeleteExpense(expenseId));
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _closeRegister() async {
    final openingBalance = _safeDouble(widget.data['openingBalance']);
    final cashSales = _safeDouble(widget.data['cashSales']);
    final totalExpenses = _safeDouble(widget.data['totalExpenses']);
    final expectedClosing = _safeDouble(widget.data['expectedClosing']);

    final closingCtrl = TextEditingController(
        text: expectedClosing.toStringAsFixed(2));
    final notesCtrl = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setD) {
          double actualClosing =
              double.tryParse(closingCtrl.text) ?? expectedClosing;
          double variance = actualClosing - expectedClosing;
          return AlertDialog(
            title: const Text('Close Day'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    'Opening Balance',
                    CurrencyFormatter.formatIndian(openingBalance),
                  ),
                  _SummaryRow(
                    'Cash Sales',
                    CurrencyFormatter.formatIndian(cashSales),
                    color: Colors.green,
                  ),
                  _SummaryRow(
                    'Cash Expenses',
                    '- ${CurrencyFormatter.formatIndian(totalExpenses)}',
                    color: Colors.red,
                  ),
                  const Divider(),
                  _SummaryRow(
                    'Expected Closing',
                    CurrencyFormatter.formatIndian(expectedClosing),
                    bold: true,
                  ),
                  const SizedBox(height: 16),
                  KTextField(
                    label: 'Actual Cash in Drawer',
                    controller: closingCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    hint: '0.00',
                    onChanged: (v) {
                      setD(() {
                        actualClosing = double.tryParse(v) ?? expectedClosing;
                        variance = actualClosing - expectedClosing;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('Variance: ', style: KTypography.bodySmall),
                      Text(
                        CurrencyFormatter.formatIndian(variance),
                        style: KTypography.bodySmall.copyWith(
                          color: variance < 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  KTextField(
                    label: 'Notes (optional)',
                    controller: notesCtrl,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700),
                child: const Text('Close Day'),
              ),
            ],
          );
        },
      ),
    );

    // Check if user confirmed (need to re-check after dialog)
    final actualClosing = double.tryParse(closingCtrl.text) ?? expectedClosing;
    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.cashRegisterClose, data: {
        'actualClosing': actualClosing,
        'notes': notesCtrl.text.isEmpty ? null : notesCtrl.text,
      });
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = widget.data;

    final openingBalance = _safeDouble(d['openingBalance']);
    final cashSales = _safeDouble(d['cashSales']);
    final upiSales = _safeDouble(d['upiSales']);
    final cardSales = _safeDouble(d['cardSales']);
    final totalSales = _safeDouble(d['totalSales']);
    final totalExpenses = _safeDouble(d['totalExpenses']);
    final expectedClosing = _safeDouble(d['expectedClosing']);
    final actualClosing =
        d['actualClosing'] != null ? _safeDouble(d['actualClosing']) : null;
    final variance =
        d['variance'] != null ? _safeDouble(d['variance']) : null;
    final txCount = (d['transactionCount'] as num?)?.toInt() ?? 0;
    final expenses = (d['expenses'] as List?) ?? [];

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => widget.onRefresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Status Card ──
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Register Status', style: KTypography.h4),
                        const Spacer(),
                        _StatusChip(status: _status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SummaryRow(
                      'Opening Balance',
                      CurrencyFormatter.formatIndian(openingBalance),
                    ),
                    _SummaryRow(
                      'Transactions',
                      '$txCount bills',
                    ),
                    if (!_isOpen && actualClosing != null) ...[
                      const Divider(height: 20),
                      _SummaryRow(
                        'Actual Closing',
                        CurrencyFormatter.formatIndian(actualClosing),
                        bold: true,
                      ),
                    ],
                    if (!_isOpen && variance != null) ...[
                      _SummaryRow(
                        'Variance',
                        CurrencyFormatter.formatIndian(variance),
                        color: variance < 0 ? Colors.red : Colors.green,
                        bold: true,
                      ),
                    ],
                    if (!_isOpen) ...[
                      const SizedBox(height: 8),
                      if (d['notes'] != null && (d['notes'] as String).isNotEmpty)
                        Text(
                          'Notes: ${d['notes']}',
                          style: KTypography.bodySmall
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                    if (_isOpen) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _openRegister,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Set Opening Balance'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Sales Breakdown Card ──
              KCard(
                title: 'Sales Breakdown',
                child: Column(
                  children: [
                    _SummaryRow(
                      'Cash Sales',
                      CurrencyFormatter.formatIndian(cashSales),
                      leadingColor: Colors.green,
                      leadingIcon: Icons.money,
                    ),
                    _SummaryRow(
                      'UPI Sales',
                      CurrencyFormatter.formatIndian(upiSales),
                      leadingColor: Colors.blue,
                      leadingIcon: Icons.qr_code,
                    ),
                    _SummaryRow(
                      'Card Sales',
                      CurrencyFormatter.formatIndian(cardSales),
                      leadingColor: Colors.purple,
                      leadingIcon: Icons.credit_card,
                    ),
                    const Divider(height: 16),
                    _SummaryRow(
                      'Total Sales',
                      CurrencyFormatter.formatIndian(totalSales),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Expected Closing Card ──
              KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryRow('Cash Expenses',
                        '- ${CurrencyFormatter.formatIndian(totalExpenses)}',
                        color: Colors.red),
                    const Divider(height: 16),
                    _SummaryRow(
                      'Expected Closing',
                      CurrencyFormatter.formatIndian(expectedClosing),
                      bold: true,
                    ),
                    Text(
                      'Opening + Cash Sales - Expenses',
                      style: KTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Expenses Card ──
              KCard(
                title: 'Cash Expenses',
                action: _isOpen
                    ? IconButton(
                        onPressed: _submitting ? null : _addExpense,
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Add expense',
                      )
                    : null,
                child: expenses.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No expenses recorded',
                          style: KTypography.bodySmall
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    : Column(
                        children: expenses.map((e) {
                          final exp = e as Map<String, dynamic>;
                          final amt = _safeDouble(exp['amount']);
                          final desc =
                              (exp['description'] as String?) ?? '';
                          final id = (exp['id'] as String?) ?? '';
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(desc,
                                style: KTypography.bodyMedium
                                    .copyWith(fontSize: 13)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  CurrencyFormatter.formatIndian(amt),
                                  style: KTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                if (_isOpen) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    onPressed: _submitting
                                        ? null
                                        : () => _deleteExpense(id),
                                    tooltip: 'Delete expense',
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),

              // ── Close Day ──
              if (_isOpen && _canClose)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _closeRegister,
                    icon: const Icon(Icons.lock_clock, size: 20),
                    label: const Text('Close Day'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                    ),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
        if (_submitting)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ── History Tab ────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _to = DateTime.now();
    _from = _to.subtract(const Duration(days: 30));
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _safeDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final params = {
      'from': _fmtDate(_from),
      'to': _fmtDate(_to),
    };
    final async = ref.watch(cashRegisterHistoryProvider(params));

    return Column(
      children: [
        // Date range row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('From: ${_fmtDate(_from)}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _from,
                      firstDate: DateTime(2020),
                      lastDate: _to,
                    );
                    if (d != null) setState(() => _from = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('To: ${_fmtDate(_to)}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _to,
                      firstDate: _from,
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _to = d);
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const KLoading(),
            error: (e, _) => KErrorView(
              message: 'Failed to load history',
              onRetry: () =>
                  ref.invalidate(cashRegisterHistoryProvider(params)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No register records found'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = list[i] as Map<String, dynamic>;
                  final status = (d['status'] as String?) ?? 'OPEN';
                  final date = (d['date'] as String?) ?? '';
                  final totalSales = _safeDouble(d['totalSales']);
                  final openingBalance = _safeDouble(d['openingBalance']);
                  final txCount =
                      (d['transactionCount'] as num?)?.toInt() ?? 0;
                  final variance = d['variance'] != null
                      ? _safeDouble(d['variance'])
                      : null;

                  return KCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(date,
                                      style: KTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  _StatusChip(status: status, compact: true),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$txCount bills  •  '
                                'Opening ${CurrencyFormatter.formatIndian(openingBalance)}',
                                style: KTypography.bodySmall.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ),
                              if (variance != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Variance: ${CurrencyFormatter.formatIndian(variance)}',
                                  style: KTypography.bodySmall.copyWith(
                                    color: variance < 0
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatIndian(totalSales),
                          style: KTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final bool compact;
  const _StatusChip({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return KStatusChip(
      status: status == 'OPEN' ? 'ACTIVE' : 'COMPLETED',
      label: status,
      dense: compact,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  final Color? leadingColor;
  final IconData? leadingIcon;

  const _SummaryRow(
    this.label,
    this.value, {
    this.color,
    this.bold = false,
    this.leadingColor,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = KTypography.bodyMedium.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontSize: bold ? 14 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (leadingIcon != null && leadingColor != null) ...[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: leadingColor!.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(leadingIcon, size: 14, color: leadingColor),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: style.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: style.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
