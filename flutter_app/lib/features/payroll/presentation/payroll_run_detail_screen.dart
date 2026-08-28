import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';

class PayrollRunDetailScreen extends ConsumerStatefulWidget {
  const PayrollRunDetailScreen({super.key, required this.runId});
  final String runId;

  @override
  ConsumerState<PayrollRunDetailScreen> createState() =>
      _PayrollRunDetailScreenState();
}

class _PayrollRunDetailScreenState
    extends ConsumerState<PayrollRunDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _run;
  List<Map<String, dynamic>> _payslips = [];
  bool _payslipsLoading = false;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchRun(), _fetchPayslips()]);
  }

  Future<void> _fetchRun() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.payrollRun(widget.runId));
      final data = response.data['data'] ?? response.data;
      _run = data is Map<String, dynamic> ? data : null;
    } on DioException catch (e) {
      final body = e.response?.data;
      _error = (body is Map ? body['message'] as String? : null) ??
          'Failed to load payroll run';
    } catch (e) {
      _error = 'Failed to load payroll run';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchPayslips() async {
    setState(() => _payslipsLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final response =
          await api.get(ApiConfig.payrollRunPayslips(widget.runId));
      final data = response.data['data'];
      if (data is List) {
        _payslips = data.cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // Payslip fetch failure is non-blocking; the header still renders.
    } finally {
      if (mounted) setState(() => _payslipsLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle actions
  // ---------------------------------------------------------------------------

  Future<void> _calculate() => _confirmAndExecute(
        title: 'Calculate Payroll',
        message: 'This will compute gross pay, deductions, and net pay for all '
            'employees in this run. Continue?',
        actionLabel: 'Calculate',
        apiCall: () async {
          final api = ref.read(apiClientProvider);
          await api.post(ApiConfig.calculatePayrollRun(widget.runId));
        },
        successMessage: 'Payroll calculated successfully',
      );

  Future<void> _approve() => _confirmAndExecute(
        title: 'Approve Payroll',
        message: 'Approving this payroll run will lock it for posting. '
            'Ensure all figures have been reviewed. Continue?',
        actionLabel: 'Approve',
        apiCall: () async {
          final api = ref.read(apiClientProvider);
          await api.post(ApiConfig.approvePayrollRun(widget.runId));
        },
        successMessage: 'Payroll approved successfully',
      );

  Future<void> _post() => _confirmAndExecute(
        title: 'Post Payroll',
        message:
            'Posting will create journal entries for salaries, deductions, '
            'and employer contributions. This action cannot be undone. Continue?',
        actionLabel: 'Post',
        apiCall: () async {
          final api = ref.read(apiClientProvider);
          await api.post(ApiConfig.postPayrollRun(widget.runId));
        },
        successMessage: 'Payroll posted successfully',
      );

  Future<void> _cancel() => _confirmAndExecute(
        title: 'Cancel Payroll Run',
        message: 'Are you sure you want to cancel this payroll run? '
            'This action cannot be undone.',
        actionLabel: 'Cancel Run',
        isDangerous: true,
        apiCall: () async {
          final api = ref.read(apiClientProvider);
          await api.post(ApiConfig.cancelPayrollRun(widget.runId));
        },
        successMessage: 'Payroll run cancelled',
      );

  Future<void> _confirmAndExecute({
    required String title,
    required String message,
    required String actionLabel,
    required Future<void> Function() apiCall,
    required String successMessage,
    bool isDangerous = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: KTypography.titleLarge),
        content: Text(message, style: KTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          if (isDangerous)
            KButton.danger(
              label: actionLabel,
              onPressed: () => Navigator.of(ctx).pop(true),
            )
          else
            KButton.primary(
              label: actionLabel,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      await apiCall();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage), backgroundColor: KColors.success),
        );
        _fetchAll();
      }
    } on DioException catch (e) {
      if (mounted) {
        final body = e.response?.data;
        final msg = (body is Map ? body['message'] as String? : null) ??
            '$actionLabel failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Run'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.payrollRuns),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const KLoading(message: 'Loading payroll run...');
    }
    if (_error != null) {
      return KErrorView(message: _error!, onRetry: _fetchAll);
    }
    if (_run == null) {
      return const KErrorView(message: 'Payroll run not found');
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView(
        padding: KSpacing.pagePadding,
        children: [
          _buildHeaderCard(),
          KSpacing.vGapMd,
          _buildSummaryCards(),
          if (_payslips.isNotEmpty) ...[
            KSpacing.vGapMd,
            _buildStatutorySection(),
          ],
          KSpacing.vGapMd,
          _buildPayslipsSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header card — period, status, employee count
  // ---------------------------------------------------------------------------

  Widget _buildHeaderCard() {
    final run = _run!;
    final status = _statusString(run);
    final periodStart = _parseDate(run['periodStart'] ?? run['periodFrom']);
    final periodEnd = _parseDate(run['periodEnd'] ?? run['periodTo']);
    final employeeCount =
        _parseInt(run['employeeCount'] ?? run['totalEmployees']);
    final notes = run['notes']?.toString();

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    run['runNumber']?.toString() ?? 'Payroll Run',
                    style: KTypography.mono(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                KStatusChip(status: status),
              ],
            ),
            KSpacing.vGapMd,
            _infoRow(
              Icons.date_range_outlined,
              'Period',
              periodStart != null && periodEnd != null
                  ? '${DateFormatter.display(periodStart)} — ${DateFormatter.display(periodEnd)}'
                  : '--',
            ),
            KSpacing.vGapXs,
            _infoRow(
              Icons.people_outline,
              'Employees',
              employeeCount > 0 ? employeeCount.toString() : '--',
            ),
            if (run['createdAt'] != null) ...[
              KSpacing.vGapXs,
              _infoRow(
                Icons.access_time_outlined,
                'Created',
                DateFormatter.dateTime(
                    DateTime.parse(run['createdAt'].toString())),
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const Divider(height: KSpacing.lg),
              Text(
                notes,
                style: KTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: KSpacing.sm),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: KTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Text(value, style: KTypography.bodyMedium)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Summary cards — gross, deductions, employer contributions, net pay
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards() {
    final run = _run!;
    final gross = _parseDouble(run['grossTotal'] ?? run['totalGross']);
    final deductions =
        _parseDouble(run['totalDeductions'] ?? run['deductions']);
    final employerContributions = _parseDouble(
        run['employerContributions'] ?? run['totalEmployerContributions']);
    final netPay = _parseDouble(run['netPay'] ?? run['totalNetPay']);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Gross Total',
                amount: gross,
                icon: Icons.account_balance_wallet_outlined,
                color: KColors.info,
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: _SummaryCard(
                label: 'Deductions',
                amount: deductions,
                icon: Icons.remove_circle_outline,
                color: KColors.warning,
              ),
            ),
          ],
        ),
        KSpacing.vGapSm,
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Employer Costs',
                amount: employerContributions,
                icon: Icons.business_outlined,
                color: KColors.draft,
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: _SummaryCard(
                label: 'Net Pay',
                amount: netPay,
                icon: Icons.payments_outlined,
                color: KColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Statutory file exports (EPFO ECR / ESIC return / bank salary advice)
  // ---------------------------------------------------------------------------

  Widget _buildStatutorySection() {
    return KCard(
      title: 'Statutory files',
      subtitle: 'Portal-ready returns generated from this run',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Wrap(
          spacing: KSpacing.sm,
          runSpacing: KSpacing.sm,
          children: [
            KButton(
              label: 'PF ECR (.txt)',
              icon: Icons.account_balance_outlined,
              variant: KButtonVariant.outlined,
              size: KButtonSize.small,
              onPressed: () => _downloadStatutoryFile(
                label: 'PF ECR',
                path: ApiConfig.payrollEcr(widget.runId),
                filename: 'ecr-${_runSlug()}.txt',
              ),
            ),
            KButton(
              label: 'ESI return (.csv)',
              icon: Icons.health_and_safety_outlined,
              variant: KButtonVariant.outlined,
              size: KButtonSize.small,
              onPressed: () => _downloadStatutoryFile(
                label: 'ESI return',
                path: ApiConfig.payrollEsiReturn(widget.runId),
                filename: 'esi-return-${_runSlug()}.csv',
              ),
            ),
            KButton(
              label: 'Bank file (.csv)',
              icon: Icons.account_balance_wallet_outlined,
              variant: KButtonVariant.outlined,
              size: KButtonSize.small,
              onPressed: _pickBankFormatAndDownload,
            ),
          ],
        ),
      ),
    );
  }

  /// Pick the corporate-banking CSV layout, then download. Mirrors the
  /// backend `BankSalaryFileGenerator.BankFormat` enum.
  Future<void> _pickBankFormatAndDownload() async {
    const formats = ['GENERIC', 'HDFC', 'ICICI', 'SBI'];
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Bank file format'),
        children: [
          for (final f in formats)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(f),
              child: Text(f == 'GENERIC' ? 'Generic CSV' : f),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    await _downloadStatutoryFile(
      label: 'Bank file ($picked)',
      path: ApiConfig.payrollBankFile(widget.runId, picked),
      filename: 'bank-salary-${picked.toLowerCase()}-${_runSlug()}.csv',
    );
  }

  /// Download a text-based statutory file (ECR / ESI / bank CSV) and hand it
  /// to the OS share/save sheet via the printing plugin (a misnomer — it
  /// shares arbitrary bytes; the `.txt`/`.csv` extension governs handling).
  /// The clipboard fallback covers desktop where the share sheet is a no-op.
  Future<void> _downloadStatutoryFile({
    required String label,
    required String path,
    required String filename,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text('Generating $label…')));
    try {
      final res = await ref.read(apiClientProvider).get(
            path,
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = (res.data as List<int>);
      if (bytes.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to export for this run')),
        );
        return;
      }
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: filename,
      );
      await Clipboard.setData(ClipboardData(text: String.fromCharCodes(bytes)));
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('$label downloaded + copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('$label download failed: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  /// Filesystem-safe slug for the run (run number when present, else the id).
  String _runSlug() {
    final num = _run?['runNumber']?.toString();
    if (num != null && num.isNotEmpty) {
      return num.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    }
    return widget.runId;
  }

  // ---------------------------------------------------------------------------
  // Payslips section
  // ---------------------------------------------------------------------------

  Widget _buildPayslipsSection() {
    if (_payslipsLoading) {
      return const KCard(
        child: Padding(
          padding: EdgeInsets.all(KSpacing.lg),
          child: Center(child: KLoading()),
        ),
      );
    }

    if (_payslips.isEmpty) {
      return const KCard(
        title: 'Payslips',
        child: KEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No payslips generated',
          subtitle:
              'Payslips will appear here after the payroll run is calculated.',
        ),
      );
    }

    return KCard(
      title: 'Payslips (${_payslips.length})',
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: KColors.draftBg,
              borderRadius: KSpacing.borderRadiusSm,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Employee',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary)),
                ),
                Expanded(
                  child: Text('Gross',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  child: Text('Deduct.',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  child: Text('Net Pay',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          KSpacing.vGapXs,
          ..._payslips.map((ps) => _PayslipRow(
                payslip: ps,
                onTap: () => _showPayslipDetail(ps),
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Payslip detail bottom sheet
  // ---------------------------------------------------------------------------

  /// Download the statutorily-compliant pay slip PDF for the given payslip id
  /// and hand it to the OS share/save sheet via the printing plugin. Same
  /// pattern as invoice/bill/BMR/food-label downloads elsewhere in the app.
  Future<void> _downloadPayslipPdf(Map<String, dynamic> payslip) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = payslip['id']?.toString();
    if (id == null || id.isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Missing payslip id')));
      return;
    }
    final name = payslip['employeeName']?.toString() ?? 'Employee';
    messenger
        .showSnackBar(SnackBar(content: Text('Rendering pay slip for $name…')));
    try {
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.payslipPdf(id),
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = res.data as List<int>;
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'payslip-$id.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Pay slip download failed: $e')));
    }
  }

  /// Download this employee's annual Form 16 (TDS-on-salary certificate) for
  /// the financial year the run falls in. The backend aggregates every posted
  /// payroll run in the FY, so any month's payslip yields the full certificate.
  Future<void> _downloadForm16(Map<String, dynamic> payslip) async {
    final messenger = ScaffoldMessenger.of(context);
    final employeeId = payslip['employeeId']?.toString();
    if (employeeId == null || employeeId.isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Missing employee id')));
      return;
    }
    final name = payslip['employeeName']?.toString() ?? 'Employee';
    final periodEnd = _parseDate(_run?['periodEnd'] ?? _run?['periodTo']);
    final fy = _fiscalYearStart(periodEnd ?? DateTime.now());
    messenger.showSnackBar(
      SnackBar(
          content: Text('Rendering Form 16 (FY $fy-${fy + 1}) for $name…')),
    );
    try {
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.tdsForm16Pdf(employeeId, fy),
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = res.data as List<int>;
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'form16-$employeeId-fy$fy.pdf',
      );
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Form 16 download failed: $e')));
    }
  }

  /// Indian fiscal year starts 1 April — Jan–Mar belong to the prior FY.
  int _fiscalYearStart(DateTime d) => d.month >= 4 ? d.year : d.year - 1;

  void _showPayslipDetail(Map<String, dynamic> payslip) {
    final employeeName = payslip['employeeName']?.toString() ?? 'Employee';
    final gross = _parseDouble(payslip['grossPay'] ?? payslip['gross']);
    final deductions =
        _parseDouble(payslip['totalDeductions'] ?? payslip['deductions']);
    final netPay = _parseDouble(payslip['netPay'] ?? payslip['net']);
    final earnings =
        (payslip['earnings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final deductionLines = (payslip['deductions'] is List
            ? payslip['deductions'] as List
            : payslip['deductionLines'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final employerLines = (payslip['employerContributions'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(employeeName, style: KTypography.h3),
                  ),
                  IconButton(
                    tooltip: 'Download pay slip PDF',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () => _downloadPayslipPdf(payslip),
                  ),
                  IconButton(
                    tooltip: 'Download Form 16',
                    icon: const Icon(Icons.workspace_premium_outlined),
                    onPressed: () => _downloadForm16(payslip),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(KSpacing.md),
                children: [
                  // Earnings
                  if (earnings.isNotEmpty) ...[
                    Text('Earnings', style: KTypography.h4),
                    KSpacing.vGapSm,
                    ...earnings.map((e) => _lineItemRow(
                          e['name']?.toString() ??
                              e['componentName']?.toString() ??
                              '--',
                          _parseDouble(e['amount']),
                        )),
                    _totalRow('Gross Pay', gross, KColors.info),
                    KSpacing.vGapMd,
                  ],
                  // Deductions
                  if (deductionLines.isNotEmpty) ...[
                    Text('Deductions', style: KTypography.h4),
                    KSpacing.vGapSm,
                    ...deductionLines.map((d) => _lineItemRow(
                          d['name']?.toString() ??
                              d['componentName']?.toString() ??
                              '--',
                          _parseDouble(d['amount']),
                        )),
                    _totalRow('Total Deductions', deductions, KColors.warning),
                    KSpacing.vGapMd,
                  ],
                  // Employer contributions
                  if (employerLines.isNotEmpty) ...[
                    Text('Employer Contributions', style: KTypography.h4),
                    KSpacing.vGapSm,
                    ...employerLines.map((ec) => _lineItemRow(
                          ec['name']?.toString() ??
                              ec['componentName']?.toString() ??
                              '--',
                          _parseDouble(ec['amount']),
                        )),
                    KSpacing.vGapMd,
                  ],
                  // Net Pay
                  const Divider(),
                  KSpacing.vGapSm,
                  _totalRow('Net Pay', netPay, KColors.success),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineItemRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: KTypography.bodyMedium),
          ),
          KMoney(amount, size: KMoneySize.small),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: KTypography.h4.copyWith(color: color),
            ),
          ),
          KMoney(
            amount,
            size: KMoneySize.medium,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom action bar
  // ---------------------------------------------------------------------------

  Widget? _buildBottomBar() {
    if (_run == null) return null;
    final status = _statusString(_run!);

    // POSTED and CANCELLED are terminal — no actions.
    if (status == 'POSTED' || status == 'CANCELLED') return null;

    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: KColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel button — available for any non-terminal status
            Expanded(
              child: KButton.danger(
                label: 'Cancel Run',
                icon: Icons.cancel_outlined,
                onPressed: _actionInProgress ? null : _cancel,
              ),
            ),
            KSpacing.hGapMd,
            // Primary action depends on current status
            Expanded(
              flex: 2,
              child: _buildPrimaryAction(status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryAction(String status) {
    switch (status) {
      case 'DRAFT':
        return KButton.primary(
          label: 'Calculate Payroll',
          icon: Icons.calculate_outlined,
          isLoading: _actionInProgress,
          onPressed: _actionInProgress ? null : _calculate,
        );
      case 'CALCULATED':
        return KButton.primary(
          label: 'Approve Payroll',
          icon: Icons.check_circle_outline,
          isLoading: _actionInProgress,
          onPressed: _actionInProgress ? null : _approve,
        );
      case 'APPROVED':
        return KButton.primary(
          label: 'Post to Accounts',
          icon: Icons.publish_outlined,
          isLoading: _actionInProgress,
          onPressed: _actionInProgress ? null : _post,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _statusString(Map<String, dynamic> run) =>
      (run['status']?.toString() ?? 'DRAFT').toUpperCase();

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

// =============================================================================
// Private widgets
// =============================================================================

/// Compact summary card for financial totals.
class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      statusAccent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          KMoney(
            amount,
            size: KMoneySize.large,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single payslip row in the table.
class _PayslipRow extends StatelessWidget {
  final Map<String, dynamic> payslip;
  final VoidCallback onTap;

  const _PayslipRow({
    required this.payslip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = payslip['employeeName']?.toString() ?? 'Unknown Employee';
    final designation = payslip['designation']?.toString();
    final gross = _parseNum(payslip['grossPay'] ?? payslip['gross']);
    final deductions =
        _parseNum(payslip['totalDeductions'] ?? payslip['deductions']);
    final net = _parseNum(payslip['netPay'] ?? payslip['net']);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: KColors.divider.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: KTypography.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (designation != null && designation.isNotEmpty)
                    Text(
                      designation,
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Expanded(
              child: KMoney(
                gross,
                size: KMoneySize.small,
              ),
            ),
            Expanded(
              child: KMoney(
                deductions,
                size: KMoneySize.small,
                style: const TextStyle(color: KColors.warning),
              ),
            ),
            Expanded(
              child: KMoney(
                net,
                size: KMoneySize.small,
                style: const TextStyle(
                  color: KColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
