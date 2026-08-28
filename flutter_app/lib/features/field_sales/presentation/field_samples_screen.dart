import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_data_table.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/field_sales_repository.dart';

/// Sample / promo material register per field salesperson (any vertical),
/// plus the org's TA/DA allowance rate configuration.
class FieldSamplesScreen extends ConsumerStatefulWidget {
  const FieldSamplesScreen({super.key});

  @override
  ConsumerState<FieldSamplesScreen> createState() => _FieldSamplesScreenState();
}

class _FieldSamplesScreenState extends ConsumerState<FieldSamplesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  List<Map<String, dynamic>> _balance = [];
  List<Map<String, dynamic>> _transactions = [];

  final _taPerKmCtrl = TextEditingController();
  final _daPerDayCtrl = TextEditingController();
  String _allowanceMode = 'FLEXIBLE';

  Dio get _dio => ref.read(apiClientProvider).dio;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _taPerKmCtrl.dispose();
    _daPerDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    try {
      final usersResp = await _dio.get<Map<String, dynamic>>(ApiConfig.orgUsers);
      final usersData =
          (usersResp.data?['data'] as List?) ?? (usersResp.data as List? ?? []);
      final settingsResp =
          await _dio.get<Map<String, dynamic>>(ApiConfig.orgSettings);
      final settings = (settingsResp.data ?? {}).cast<String, dynamic>();

      if (mounted) {
        setState(() {
          _users = usersData
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          _taPerKmCtrl.text =
              settings['field_sales.ta_per_km']?.toString() ?? '';
          _daPerDayCtrl.text =
              settings['field_sales.da_per_day']?.toString() ?? '';
          _allowanceMode =
              settings['field_sales.allowance_mode']?.toString() ?? 'FLEXIBLE';
        });
      }
    } catch (e) {
      _toast('Failed to load settings: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSalesperson(String userId) async {
    setState(() => _selectedUserId = userId);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.sampleBalance(userId),
        repo.sampleTransactions(userId),
      ]);
      if (mounted) {
        setState(() {
          _balance = results[0];
          _transactions = results[1];
        });
      }
    } catch (e) {
      _toast('Failed to load samples: $e', isError: true);
    }
  }

  Future<void> _saveRates() async {
    try {
      await _dio.put<Map<String, dynamic>>(ApiConfig.orgSettings, data: {
        'field_sales.ta_per_km':
            _taPerKmCtrl.text.trim().isEmpty ? '0' : _taPerKmCtrl.text.trim(),
        'field_sales.da_per_day':
            _daPerDayCtrl.text.trim().isEmpty ? '0' : _daPerDayCtrl.text.trim(),
        'field_sales.allowance_mode': _allowanceMode,
      });
      _toast('Allowance rates saved successfully');
    } catch (e) {
      _toast('Failed to save rates: $e', isError: true);
    }
  }

  Future<void> _recordTxn({required bool isIssue}) async {
    if (_selectedUserId == null) return;
    final productCtl = TextEditingController();
    final qtyCtl = TextEditingController();
    final notesCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIssue ? 'Issue Samples / Promo Material' : 'Record Sample Return'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KTextField(
                controller: productCtl,
                label: 'Product / Material Name *',
                hint: 'e.g. Paracetamol 650mg Trial Packs',
              ),
              KSpacing.vGapSm,
              KTextField(
                controller: qtyCtl,
                label: 'Quantity *',
                hint: 'e.g. 50',
                keyboardType: TextInputType.number,
              ),
              KSpacing.vGapSm,
              KTextField(
                controller: notesCtl,
                label: 'Remarks (Optional)',
                hint: 'e.g. Batch # or campaign details',
              ),
            ],
          ),
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            label: isIssue ? 'Issue Samples' : 'Record Return',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final qty = int.tryParse(qtyCtl.text) ?? 0;
    if (productCtl.text.trim().isEmpty || qty <= 0) {
      _toast('Product and a positive quantity are required', isError: true);
      return;
    }
    try {
      await ref.read(fieldSalesRepositoryProvider).recordSampleTxn(
            isIssue: isIssue,
            salespersonId: _selectedUserId!,
            productName: productCtl.text.trim(),
            quantity: qty,
            notes: notesCtl.text.trim(),
          );
      _toast(isIssue ? 'Samples issued' : 'Return recorded');
      await _loadSalesperson(_selectedUserId!);
    } catch (e) {
      _toast('Failed: $e', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? KColors.error : KColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Samples & Travel Allowance')),
      body: _isLoading
          ? const Center(child: KLoading())
          : ListView(
              padding: KSpacing.pagePadding,
              children: [
                // -- TA/DA Settings Card --
                KCard(
                  title: 'TA / DA Travel Allowance Rates',
                  subtitle: 'Configure daily allowance and per-kilometer travel reimbursement rates.',
                  leading: const Icon(Icons.directions_car_outlined, color: KColors.primary),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _allowanceMode,
                        decoration: const InputDecoration(
                          labelText: 'Distance claiming mode',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'FLEXIBLE',
                            child: Text('Flexible — GPS distance prefilled, salesperson may adjust'),
                          ),
                          DropdownMenuItem(
                            value: 'GPS',
                            child: Text('GPS Strict — claim exactly the tracked distance'),
                          ),
                          DropdownMenuItem(
                            value: 'MANUAL',
                            child: Text('Manual — salesperson enters distance manually'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _allowanceMode = v ?? 'FLEXIBLE'),
                      ),
                      KSpacing.vGapMd,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: KTextField.amount(
                              controller: _taPerKmCtrl,
                              label: 'TA rate per km',
                            ),
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            child: KTextField.amount(
                              controller: _daPerDayCtrl,
                              label: 'DA rate per day',
                            ),
                          ),
                          KSpacing.hGapSm,
                          KButton.primary(
                            label: 'Save Rates',
                            icon: Icons.save_outlined,
                            onPressed: _saveRates,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                KSpacing.vGapLg,

                // -- Sample Register Section --
                KCard(
                  title: 'Sample & Promotional Material Register',
                  subtitle: 'Select a field salesperson to view stock in-hand, issuances, and returns.',
                  leading: const Icon(Icons.medical_services_outlined, color: KColors.primary),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedUserId,
                        decoration: const InputDecoration(
                          labelText: 'Select Field Salesperson',
                          border: OutlineInputBorder(),
                        ),
                        items: _users
                            .map((u) => DropdownMenuItem(
                                  value: (u['userId'] ?? u['id'])?.toString(),
                                  child: Text(
                                      '${u['fullName'] ?? u['displayName'] ?? u['email'] ?? ''}'
                                      '${u['role'] != null ? ' (${u['role']})' : ''}'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _loadSalesperson(v);
                        },
                      ),
                      if (_selectedUserId != null) ...[
                        KSpacing.vGapMd,
                        Row(
                          children: [
                            KButton.primary(
                              label: 'Issue Samples',
                              icon: Icons.add_box_outlined,
                              onPressed: () => _recordTxn(isIssue: true),
                            ),
                            KSpacing.hGapSm,
                            KButton.outlined(
                              label: 'Record Return',
                              icon: Icons.keyboard_return,
                              onPressed: () => _recordTxn(isIssue: false),
                            ),
                          ],
                        ),
                        KSpacing.vGapMd,
                        if (_balance.isEmpty)
                          const KEmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'No sample balance records',
                            subtitle: 'No promotional or sample items currently assigned to this salesperson.',
                          )
                        else
                          KDataTable(
                            columns: const [
                              KTableColumn(label: 'Product / Material'),
                              KTableColumn(label: 'Issued', numeric: true),
                              KTableColumn(label: 'Returned', numeric: true),
                              KTableColumn(label: 'Distributed', numeric: true),
                              KTableColumn(label: 'Balance In-Hand', numeric: true),
                            ],
                            rows: _balance.map((r) {
                              final bal = (r['balance'] as num?) ?? 0;
                              return [
                                Text(
                                  r['productName']?.toString() ?? '',
                                  style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${r['issued'] ?? 0}',
                                  style: KTypography.mono(fontSize: 12),
                                ),
                                Text(
                                  '${r['returned'] ?? 0}',
                                  style: KTypography.mono(fontSize: 12),
                                ),
                                Text(
                                  '${r['distributed'] ?? 0}',
                                  style: KTypography.mono(fontSize: 12),
                                ),
                                Text(
                                  '$bal',
                                  style: KTypography.mono(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: bal < 0 ? KColors.error : KColors.success,
                                  ),
                                ),
                              ];
                            }).toList(),
                          ),
                        if (_transactions.isNotEmpty) ...[
                          KSpacing.vGapLg,
                          Text('Recent Sample Movements', style: KTypography.titleMedium),
                          KSpacing.vGapSm,
                          ..._transactions.take(15).map((t) {
                            final isIssue = t['txnType'] == 'ISSUE';
                            final txnDate = t['txnDate']?.toString() ?? '--';
                            final notes = t['notes']?.toString();

                            return KCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isIssue
                                        ? KColors.success.withValues(alpha: 0.12)
                                        : KColors.warning.withValues(alpha: 0.12),
                                    child: Icon(
                                      isIssue ? Icons.add_box_outlined : Icons.keyboard_return,
                                      color: isIssue ? KColors.success : KColors.warning,
                                      size: 18,
                                    ),
                                  ),
                                  KSpacing.hGapMd,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${t['productName']} × ${t['quantity']}',
                                          style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        KSpacing.vGapXxs,
                                        Row(
                                          children: [
                                            KStatusChip(
                                              status: isIssue ? 'ISSUE' : 'RETURN',
                                              label: isIssue ? 'Issued' : 'Returned',
                                            ),
                                            KSpacing.hGapSm,
                                            Text(
                                              txnDate,
                                              style: KTypography.mono(fontSize: 11, color: KColors.textSecondary),
                                            ),
                                            if (notes != null && notes.isNotEmpty) ...[
                                              const Text(' • ', style: TextStyle(color: KColors.textSecondary)),
                                              Expanded(
                                                child: Text(
                                                  notes,
                                                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
