import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import 'widgets/three_way_match_detail_sheet.dart';

/// 3-Way Match Inbox — the AP control surface that surfaces vendor bills
/// whose PO ↔ GRN ↔ Bill comparison threw an EXCEPTION (qty over, price hike,
/// missing PO, missing GRN), plus the org-level tolerance settings.
///
/// Backend: `ThreeWayMatchService` (commits 24a9643 + bb597a7). Exception
/// rows are written to `bill_match_result_line` and the same data also
/// drops a `THREE_WAY_MATCH_EXCEPTION` AI Inbox suggestion — this screen
/// is the dedicated drill-in for the AP team.
///
/// Design tokens: KStatusChip / KMoney / KCard / KTypography.mono /
/// KSpacing / KEmptyState / KButton / KTextField — no raw money Text,
/// no invented colours.
class ThreeWayMatchInboxScreen extends ConsumerStatefulWidget {
  const ThreeWayMatchInboxScreen({super.key});

  @override
  ConsumerState<ThreeWayMatchInboxScreen> createState() =>
      _ThreeWayMatchInboxScreenState();
}

class _ThreeWayMatchInboxScreenState
    extends ConsumerState<ThreeWayMatchInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
        title: const Text('3-Way Match Inbox'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.report_problem_outlined),
              text: 'Exceptions',
            ),
            Tab(
              icon: Icon(Icons.tune_rounded),
              text: 'Settings',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ExceptionsTab(),
          _SettingsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions tab
// ─────────────────────────────────────────────────────────────────────────────

class _ExceptionsQuery {
  final DateTimeRange? range;
  const _ExceptionsQuery(this.range);
  @override
  bool operator ==(Object o) =>
      o is _ExceptionsQuery &&
      o.range?.start == range?.start &&
      o.range?.end == range?.end;
  @override
  int get hashCode => Object.hash(range?.start, range?.end);
}

final _exceptionsProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, _ExceptionsQuery>(
        (ref, q) async {
  final qs = <String, dynamic>{
    'page': 0,
    'size': 200,
    if (q.range != null) ...{
      'from': DateFormat('yyyy-MM-dd').format(q.range!.start),
      'to': DateFormat('yyyy-MM-dd').format(q.range!.end),
    }
  };
  final res = await ref
      .read(apiClientProvider)
      .get(ApiConfig.threeWayMatchExceptions, queryParameters: qs);
  final body = res.data;
  // Tolerant unwrapping — endpoint returns ApiResponse.ok(...) wrapping either
  // a Page<...> {content:[...]} or a bare list.
  dynamic payload = body;
  if (payload is Map && payload['data'] != null) payload = payload['data'];
  if (payload is Map && payload['content'] != null) payload = payload['content'];
  if (payload is List) {
    return payload.whereType<Map<String, dynamic>>().toList();
  }
  return const [];
});

class _ExceptionsTab extends ConsumerStatefulWidget {
  const _ExceptionsTab();

  @override
  ConsumerState<_ExceptionsTab> createState() => _ExceptionsTabState();
}

class _ExceptionsTabState extends ConsumerState<_ExceptionsTab> {
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  void _clearRange() => setState(() => _range = null);

  @override
  Widget build(BuildContext context) {
    final query = _ExceptionsQuery(_range);
    final async = ref.watch(_exceptionsProvider(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateRangeBar(
          range: _range,
          onPick: _pickRange,
          onClear: _range == null ? null : _clearRange,
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md),
                child: Text(
                  ApiErrorParser.message(e),
                  style: TextStyle(color: KColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(KSpacing.lg),
                    child: KEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'No exceptions',
                      subtitle:
                          'Every recent vendor bill matched its PO and GRN cleanly. '
                          'Mismatches surface here automatically when a bill is created.',
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(_exceptionsProvider(query)),
                child: ListView.separated(
                  padding: EdgeInsets.all(KSpacing.md),
                  itemBuilder: (_, i) =>
                      _ExceptionRowCard(row: rows[i], onChanged: () {
                        ref.invalidate(_exceptionsProvider(query));
                      }),
                  separatorBuilder: (_, __) =>
                      SizedBox(height: KSpacing.sm),
                  itemCount: rows.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DateRangeBar extends StatelessWidget {
  final DateTimeRange? range;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  const _DateRangeBar(
      {required this.range, required this.onPick, this.onClear});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    final label = range == null
        ? 'All exceptions'
        : '${df.format(range!.start)} → ${df.format(range!.end)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
          KSpacing.md, KSpacing.sm, KSpacing.md, 0),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded,
              size: 16, color: KColors.textSecondary),
          SizedBox(width: KSpacing.xs),
          TextButton(onPressed: onPick, child: Text(label)),
          if (onClear != null)
            IconButton(
              tooltip: 'Clear date filter',
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

class _ExceptionRowCard extends ConsumerWidget {
  final Map<String, dynamic> row;
  final VoidCallback onChanged;
  const _ExceptionRowCard({required this.row, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The /exceptions endpoint returns raw BillMatchResultLine rows (camelCase
    // via Lombok). Headline-level fields (billNumber/vendorName/totalAmount)
    // aren't joined in yet — we surface what we have and let "View details"
    // (which hits GET /{billId} → MatchSnapshot) fill in the rest.
    final billId = row['billId']?.toString();
    final billNumber =
        row['billNumber']?.toString() ?? _shortId(billId) ?? '—';
    final vendor = row['vendorName']?.toString();
    final billDate = row['billDate']?.toString();
    final status = row['status']?.toString() ?? 'EXCEPTION';
    final billedQty =
        (row['billedQty'] as num?)?.toDouble() ?? 0;
    final billPrice =
        (row['billUnitPrice'] as num?)?.toDouble() ?? 0;
    final lineAmount = billedQty * billPrice;
    final variance = (row['amountVariance'] as num?)?.toDouble() ??
        (row['priceVariance'] as num?)?.toDouble() ??
        0;

    return KCard(
      padding: EdgeInsets.all(KSpacing.sm),
      onTap: billId == null
          ? null
          : () => ThreeWayMatchDetailSheet.show(
                context,
                billId,
                onChanged: onChanged,
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(billNumber, style: KTypography.mono()),
                    if (vendor != null && vendor.isNotEmpty) ...[
                      SizedBox(height: KSpacing.xxs),
                      Text(
                        vendor,
                        style: KTypography.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (billDate != null && billDate.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: KSpacing.xxs),
                        child: Text(
                          _fmtDate(billDate),
                          style: KTypography.bodySmall.copyWith(
                            color: KColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              KStatusChip(status: status),
            ],
          ),
          SizedBox(height: KSpacing.sm),
          // Bottom metric row: line amount + variance.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Line amount',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                    KMoney(lineAmount),
                  ],
                ),
              ),
              if (variance != 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Variance',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                    KMoney(variance, colorBySign: true),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtDate(String iso) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  static String? _shortId(String? id) {
    if (id == null || id.isEmpty) return null;
    return id.length > 8 ? id.substring(0, 8) : id;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings tab
// ─────────────────────────────────────────────────────────────────────────────

final _settingsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res =
      await ref.read(apiClientProvider).get(ApiConfig.threeWayMatchSettings);
  final body = res.data;
  dynamic payload = body;
  if (payload is Map && payload['data'] != null) payload = payload['data'];
  if (payload is Map) {
    return payload.cast<String, dynamic>();
  }
  return const {};
});

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role;
    final canEdit = role == 'OWNER' || role == 'ADMIN';
    if (!canEdit) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(KSpacing.lg),
          child: KEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Settings restricted',
            subtitle:
                '3-Way Match tolerances can only be edited by OWNER or ADMIN.',
          ),
        ),
      );
    }
    final async = ref.watch(_settingsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: EdgeInsets.all(KSpacing.md),
          child: Text(
            ApiErrorParser.message(e),
            style: TextStyle(color: KColors.error),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (settings) => _SettingsForm(initial: settings),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> initial;
  const _SettingsForm({required this.initial});

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late bool _required;
  late TextEditingController _qtyTolPct;
  late TextEditingController _priceTolAbs;
  late TextEditingController _priceTolPct;
  late TextEditingController _bypassThreshold;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _required = _bool(s['required'], defaultValue: true);
    _qtyTolPct = TextEditingController(text: _str(s['qty_tolerance_pct'], '0'));
    _priceTolAbs =
        TextEditingController(text: _str(s['price_tolerance_abs'], '1'));
    _priceTolPct =
        TextEditingController(text: _str(s['price_tolerance_pct'], '0.005'));
    _bypassThreshold =
        TextEditingController(text: _str(s['bypass_threshold'], '0'));
  }

  @override
  void dispose() {
    _qtyTolPct.dispose();
    _priceTolAbs.dispose();
    _priceTolPct.dispose();
    _bypassThreshold.dispose();
    super.dispose();
  }

  static bool _bool(dynamic v, {required bool defaultValue}) {
    if (v is bool) return v;
    final s = v?.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return defaultValue;
  }

  static String _str(dynamic v, String fallback) {
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).put(
        ApiConfig.threeWayMatchSettings,
        data: {
          'required': _required.toString(),
          'qty_tolerance_pct': _qtyTolPct.text.trim(),
          'price_tolerance_abs': _priceTolAbs.text.trim(),
          'price_tolerance_pct': _priceTolPct.text.trim(),
          'bypass_threshold': _bypassThreshold.text.trim(),
        },
      );
      ref.invalidate(_settingsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('3-Way Match settings saved')),
      );
    } on DioException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateNumber(String? v,
      {bool allowZero = true, double? min, double? max}) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final d = double.tryParse(v.trim());
    if (d == null) return 'Must be a number';
    if (!allowZero && d == 0) return 'Must be > 0';
    if (d < 0) return 'Must be ≥ 0';
    if (min != null && d < min) return 'Must be ≥ $min';
    if (max != null && d > max) return 'Must be ≤ $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(KSpacing.md),
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Match policy', style: KTypography.titleSmall),
                SizedBox(height: KSpacing.xs),
                Text(
                  'Controls how strict the PO ↔ GRN ↔ Bill comparison is. '
                  'Exceptions always surface in this inbox; the toggle below '
                  'governs whether they also block bill payment.',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
                SizedBox(height: KSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Block payment on exception'),
                  subtitle: Text(
                    _required
                        ? 'Bills with exceptions cannot be paid until overridden.'
                        : 'Exceptions are surfaced but never block payment.',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                  ),
                  value: _required,
                  onChanged: (v) => setState(() => _required = v),
                ),
              ],
            ),
          ),
          SizedBox(height: KSpacing.md),
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tolerances', style: KTypography.titleSmall),
                SizedBox(height: KSpacing.md),
                KTextField(
                  label: 'Quantity over-receipt tolerance (%)',
                  hint: 'e.g. 2 = allow billing up to 2% above received qty',
                  controller: _qtyTolPct,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      _validateNumber(v, allowZero: true, max: 100),
                ),
                SizedBox(height: KSpacing.md),
                KTextField(
                  label: 'Absolute price tolerance (₹)',
                  hint: 'e.g. 1 = ignore unit price differences ≤ ₹1',
                  controller: _priceTolAbs,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateNumber(v, allowZero: true),
                ),
                SizedBox(height: KSpacing.md),
                KTextField(
                  label: 'Relative price tolerance (decimal, e.g. 0.005 = 0.5%)',
                  hint: '0.005 = 0.5%, 0.01 = 1%',
                  controller: _priceTolPct,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                      _validateNumber(v, allowZero: true, max: 1),
                ),
                SizedBox(height: KSpacing.md),
                KTextField(
                  label: 'Bypass threshold (₹)',
                  hint: 'Bills below this total are auto-bypassed (0 = off)',
                  controller: _bypassThreshold,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _validateNumber(v, allowZero: true),
                ),
              ],
            ),
          ),
          SizedBox(height: KSpacing.lg),
          KButton(
            label: 'Save settings',
            icon: Icons.save_outlined,
            isLoading: _saving,
            fullWidth: true,
            onPressed: _saving ? null : _save,
          ),
          SizedBox(height: KSpacing.lg),
        ],
      ),
    );
  }
}
