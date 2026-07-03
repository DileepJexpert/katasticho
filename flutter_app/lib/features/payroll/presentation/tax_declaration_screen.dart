import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Form 12BB — employee tax declaration (Rule 26C). Self-service "My
/// Declaration" tab for any employee + an "HR Review" tab for payroll admins
/// to verify and download the signed PDF. Backend: `TaxDeclarationService`
/// + `Form12BBPdfService` (`/api/v1/payroll/tax-declarations`).
class TaxDeclarationScreen extends ConsumerStatefulWidget {
  const TaxDeclarationScreen({super.key});

  @override
  ConsumerState<TaxDeclarationScreen> createState() =>
      _TaxDeclarationScreenState();
}

class _TaxDeclarationScreenState extends ConsumerState<TaxDeclarationScreen> {
  late String _fy = _currentFy();

  static String _currentFy() {
    final now = DateTime.now();
    final start = now.month >= 4 ? now.year : now.year - 1;
    final next = ((start + 1) % 100).toString().padLeft(2, '0');
    return '$start-$next';
  }

  static List<String> _fyOptions() {
    final cur = _currentFy();
    final startYear = int.parse(cur.split('-').first);
    return [
      for (var y = startYear + 1; y >= startYear - 3; y--)
        '$y-${((y + 1) % 100).toString().padLeft(2, '0')}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tax Declaration (Form 12BB)'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
              child: DropdownButton<String>(
                value: _fy,
                underline: const SizedBox.shrink(),
                items: [
                  for (final fy in _fyOptions())
                    DropdownMenuItem(value: fy, child: Text('FY $fy')),
                ],
                onChanged: (v) => setState(() => _fy = v ?? _fy),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Declaration'),
              Tab(text: 'HR Review'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyDeclarationTab(fy: _fy),
            _HrReviewTab(fy: _fy),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// My Declaration (self-service)
// ───────────────────────────────────────────────────────────────────────────

class _MyDeclarationTab extends ConsumerStatefulWidget {
  const _MyDeclarationTab({required this.fy});
  final String fy;

  @override
  ConsumerState<_MyDeclarationTab> createState() => _MyDeclarationTabState();
}

class _MyDeclarationTabState extends ConsumerState<_MyDeclarationTab> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _decl;

  String _regime = 'OLD';
  bool _metro = false;

  final _rent = TextEditingController();
  final _landlordPan = TextEditingController();
  final _lta = TextEditingController();
  final _homeLoan = TextEditingController();
  final _otherIncome = TextEditingController();
  final _notes = TextEditingController();
  final _c80c = TextEditingController();
  final _c80ccd1b = TextEditingController();
  final _c80dSelf = TextEditingController();
  final _c80dParents = TextEditingController();
  final _c80e = TextEditingController();
  final _c80g = TextEditingController();
  final _c80tta = TextEditingController();
  final _c80ttb = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _MyDeclarationTab old) {
    super.didUpdateWidget(old);
    if (old.fy != widget.fy) _load();
  }

  @override
  void dispose() {
    for (final c in [
      _rent,
      _landlordPan,
      _lta,
      _homeLoan,
      _otherIncome,
      _notes,
      _c80c,
      _c80ccd1b,
      _c80dSelf,
      _c80dParents,
      _c80e,
      _c80g,
      _c80tta,
      _c80ttb,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _status => (_decl?['status']?.toString() ?? 'DRAFT').toUpperCase();
  bool get _editable => _decl == null || _status == 'DRAFT';
  String? get _id => _decl?['id']?.toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConfig.taxDeclarationMe(widget.fy));
      _decl = res.data['data'] as Map<String, dynamic>?;
      _fill(_decl);
    } on DioException catch (e) {
      _error = _msg(e) ?? 'Failed to load declaration';
    } catch (_) {
      _error = 'Failed to load declaration';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(Map<String, dynamic>? d) {
    _regime = (d?['taxRegime']?.toString() ?? 'OLD').toUpperCase();
    if (_regime != 'OLD' && _regime != 'NEW') _regime = 'OLD';
    _metro = d?['hraMetroCity'] == true;
    _rent.text = _s(d?['hraRentPaid']);
    _landlordPan.text = d?['landlordPan']?.toString() ?? '';
    _lta.text = _s(d?['ltaClaim']);
    _homeLoan.text = _s(d?['homeLoanInterest']);
    _otherIncome.text = _s(d?['otherIncome']);
    _notes.text = d?['notes']?.toString() ?? '';
    _c80c.text = _s(d?['deduction80c']);
    _c80ccd1b.text = _s(d?['deduction80ccd1b']);
    _c80dSelf.text = _s(d?['deduction80dSelf']);
    _c80dParents.text = _s(d?['deduction80dParents']);
    _c80e.text = _s(d?['deduction80e']);
    _c80g.text = _s(d?['deduction80g']);
    _c80tta.text = _s(d?['deduction80tta']);
    _c80ttb.text = _s(d?['deduction80ttb']);
  }

  static String _s(dynamic v) {
    if (v == null) return '';
    final n = v is num ? v : num.tryParse(v.toString());
    if (n == null) return '';
    if (n == 0) return '';
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  double? _num(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', ''));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final body = <String, dynamic>{
        'taxRegime': _regime,
        'hraRentPaid': _num(_rent),
        'hraMetroCity': _metro,
        'landlordPan':
            _landlordPan.text.trim().isEmpty ? null : _landlordPan.text.trim(),
        'ltaClaim': _num(_lta),
        'homeLoanInterest': _num(_homeLoan),
        'otherIncome': _num(_otherIncome),
        'deduction80c': _num(_c80c),
        'deduction80ccd1b': _num(_c80ccd1b),
        'deduction80dSelf': _num(_c80dSelf),
        'deduction80dParents': _num(_c80dParents),
        'deduction80e': _num(_c80e),
        'deduction80g': _num(_c80g),
        'deduction80tta': _num(_c80tta),
        'deduction80ttb': _num(_c80ttb),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      };
      final res = await ref.read(apiClientProvider).put(
            ApiConfig.taxDeclarationMe(widget.fy),
            data: body,
          );
      _decl = res.data['data'] as Map<String, dynamic>?;
      _fill(_decl);
      messenger
          .showSnackBar(const SnackBar(content: Text('Declaration saved')));
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(_msg(e) ?? 'Save failed'),
        backgroundColor: KColors.error,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    final id = _id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit declaration'),
        content: const Text(
            'Once submitted, the declaration is locked for HR review and can '
            'no longer be edited. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(apiClientProvider)
          .post(ApiConfig.taxDeclarationSubmit(id));
      messenger
          .showSnackBar(const SnackBar(content: Text('Declaration submitted')));
      _load();
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(_msg(e) ?? 'Submit failed'),
        backgroundColor: KColors.error,
      ));
    }
  }

  Future<void> _downloadPdf() async {
    final id = _id;
    if (id == null) return;
    await downloadForm12BB(ref, context, id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const KLoading(message: 'Loading declaration…');
    if (_error != null) return KErrorView(message: _error!, onRetry: _load);

    final newRegime = _regime == 'NEW';

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        // Status + regime
        KCard(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('FY ${widget.fy}', style: KTypography.h3),
                    ),
                    KStatusChip(status: _status),
                  ],
                ),
                KSpacing.vGapMd,
                DropdownButtonFormField<String>(
                  initialValue: _regime,
                  decoration: const InputDecoration(
                    labelText: 'Tax regime',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'OLD', child: Text('Old regime')),
                    DropdownMenuItem(
                        value: 'NEW', child: Text('New regime (115BAC)')),
                  ],
                  onChanged: _editable
                      ? (v) => setState(() => _regime = v ?? 'OLD')
                      : null,
                ),
                if (newRegime) ...[
                  KSpacing.vGapSm,
                  _infoBanner(
                      'Under the new regime, HRA exemption and most Chapter VI-A '
                      'deductions don\'t apply. Figures below are kept for record only.'),
                ],
              ],
            ),
          ),
        ),
        KSpacing.vGapMd,

        // 1. HRA
        _section('1. House Rent Allowance', [
          _money('Annual rent paid', _rent),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _metro,
            onChanged: _editable ? (v) => setState(() => _metro = v) : null,
            title: const Text('Metro city (Delhi/Mumbai/Kolkata/Chennai)'),
            subtitle: const Text('50% of basic vs 40% for non-metro'),
          ),
          KTextField(
            label: 'Landlord PAN (if annual rent > ₹1,00,000)',
            controller: _landlordPan,
            enabled: _editable,
            prefixIcon: Icons.badge_outlined,
          ),
        ]),

        // 2. LTA / 3. home loan
        _section('2. Leave Travel Concession', [
          _money('LTA / LTC claimed', _lta),
        ]),
        _section('3. Interest on home loan (Sec 24)', [
          _money('Interest paid / payable', _homeLoan),
        ]),

        // 4. Chapter VI-A
        _section('4. Chapter VI-A deductions', [
          _money('80C — LIC / PF / ELSS / tuition / principal', _c80c),
          _money('80CCD(1B) — NPS (extra ₹50,000)', _c80ccd1b),
          _money('80D — Medical insurance (self & family)', _c80dSelf),
          _money('80D — Medical insurance (parents)', _c80dParents),
          _money('80E — Education-loan interest', _c80e),
          _money('80G — Donations', _c80g),
          _money('80TTA — Savings interest', _c80tta),
          _money('80TTB — Interest income (senior citizen)', _c80ttb),
        ]),

        // 5. other income + notes
        _section('5. Other income & notes', [
          _money('Other income reported to employer', _otherIncome),
          KTextField(
            label: 'Notes',
            controller: _notes,
            enabled: _editable,
            maxLines: 2,
            prefixIcon: Icons.notes_outlined,
          ),
        ]),

        KSpacing.vGapMd,
        if (_editable)
          Row(
            children: [
              Expanded(
                child: KButton(
                  label: 'Save draft',
                  icon: Icons.save_outlined,
                  variant: KButtonVariant.outlined,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: KButton(
                  label: 'Submit',
                  icon: Icons.send_outlined,
                  onPressed: (_saving || _id == null) ? null : _submit,
                ),
              ),
            ],
          )
        else
          KButton(
            label: 'Download Form 12BB',
            icon: Icons.picture_as_pdf_outlined,
            variant: KButtonVariant.outlined,
            onPressed: _downloadPdf,
          ),
        if (_editable && _id != null) ...[
          KSpacing.vGapSm,
          KButton(
            label: 'Download Form 12BB',
            icon: Icons.picture_as_pdf_outlined,
            variant: KButtonVariant.text,
            onPressed: _downloadPdf,
          ),
        ],
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: KCard(
        title: title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) KSpacing.vGapSm,
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _money(String label, TextEditingController c) {
    return KTextField(
      label: label,
      controller: c,
      enabled: _editable,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: Icons.currency_rupee,
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: KColors.warning.withValues(alpha: 0.1),
        borderRadius: KSpacing.borderRadiusSm,
        border: Border.all(color: KColors.warning.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
    );
  }

  static String? _msg(DioException e) {
    final body = e.response?.data;
    return body is Map ? body['message'] as String? : null;
  }
}

// ───────────────────────────────────────────────────────────────────────────
// HR Review (payroll admins)
// ───────────────────────────────────────────────────────────────────────────

class _HrReviewTab extends ConsumerStatefulWidget {
  const _HrReviewTab({required this.fy});
  final String fy;

  @override
  ConsumerState<_HrReviewTab> createState() => _HrReviewTabState();
}

class _HrReviewTabState extends ConsumerState<_HrReviewTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  final Map<String, String> _names = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _HrReviewTab old) {
    super.didUpdateWidget(old);
    if (old.fy != widget.fy) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      // Employee name map (best-effort) for friendly display.
      try {
        final emp = await api.get(ApiConfig.payrollEmployees);
        final list = (emp.data['data'] as List?) ?? const [];
        _names.clear();
        for (final e in list.cast<Map<String, dynamic>>()) {
          final id = e['id']?.toString();
          if (id != null) {
            _names[id] = e['fullName']?.toString() ?? id;
          }
        }
      } catch (_) {/* names are optional */}

      final res = await api.get(ApiConfig.taxDeclarationList(widget.fy));
      final list = (res.data['data'] as List?) ?? const [];
      _rows = list.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      _error = code == 403
          ? 'HR Review requires a payroll admin role (OWNER / ADMIN / ACCOUNTANT).'
          : (e.response?.data is Map
                  ? (e.response!.data['message'] as String?)
                  : null) ??
              'Failed to load declarations';
    } catch (_) {
      _error = 'Failed to load declarations';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(apiClientProvider)
          .post(ApiConfig.taxDeclarationVerify(id));
      messenger
          .showSnackBar(const SnackBar(content: Text('Declaration verified')));
      _load();
    } on DioException catch (e) {
      final body = e.response?.data;
      messenger.showSnackBar(SnackBar(
        content: Text((body is Map ? body['message'] as String? : null) ??
            'Verify failed'),
        backgroundColor: KColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const KLoading(message: 'Loading declarations…');
    if (_error != null) return KErrorView(message: _error!, onRetry: _load);
    if (_rows.isEmpty) {
      return KEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No declarations',
        subtitle: 'No employee has filed a Form 12BB for FY ${widget.fy} yet.',
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: _rows.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (_, i) {
          final r = _rows[i];
          final empId = r['employeeId']?.toString() ?? '';
          final name = _names[empId] ??
              (empId.length > 8 ? empId.substring(0, 8) : empId);
          final status = (r['status']?.toString() ?? 'DRAFT').toUpperCase();
          final id = r['id']?.toString();
          return KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: KTypography.labelLarge),
                        KSpacing.vGapXs,
                        Text('Regime: ${r['taxRegime'] ?? '--'}',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                      ],
                    ),
                  ),
                  KStatusChip(status: status),
                  IconButton(
                    tooltip: 'Download Form 12BB',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: id == null
                        ? null
                        : () => downloadForm12BB(ref, context, id),
                  ),
                  if (status == 'SUBMITTED')
                    KButton(
                      label: 'Verify',
                      size: KButtonSize.small,
                      onPressed: () => _verify(r),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shared Form 12BB PDF download — fetches bytes and hands them to the OS
/// share/save sheet via the printing plugin.
Future<void> downloadForm12BB(
    WidgetRef ref, BuildContext context, String id) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Rendering Form 12BB…')));
  try {
    final res = await ref.read(apiClientProvider).get(
          ApiConfig.taxDeclarationPdf(id),
          options: Options(responseType: ResponseType.bytes),
        );
    final bytes = res.data as List<int>;
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'form12bb-$id.pdf',
    );
  } catch (e) {
    messenger
        .showSnackBar(SnackBar(content: Text('Form 12BB download failed: $e')));
  }
}
