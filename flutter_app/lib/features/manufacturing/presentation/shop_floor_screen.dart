import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Mobile-first shop-floor screen for production operators.
class ShopFloorScreen extends ConsumerStatefulWidget {
  const ShopFloorScreen({super.key});

  @override
  ConsumerState<ShopFloorScreen> createState() => _ShopFloorScreenState();
}

class _ShopFloorScreenState extends ConsumerState<ShopFloorScreen> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();
  bool _looking = false;
  Map<String, dynamic>? _wo;
  List<Map<String, dynamic>> _jobCards = const [];
  List<Map<String, dynamic>> _activeWos = const [];
  List<Map<String, dynamic>> _reasonCodes = const [];
  bool _loadingActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanFocus.requestFocus());
    _loadActiveWos();
    _loadReasonCodes();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? const [];

  Future<void> _loadActiveWos() async {
    try {
      final res = await ref.read(apiClientProvider).get(
        ApiConfig.manufacturingWorkOrders,
        queryParameters: {'status': 'IN_PROGRESS', 'pageSize': 50},
      );
      final data = res.data['data'];
      List<Map<String, dynamic>> items;
      if (data is Map && data['content'] is List) {
        items = (data['content'] as List).cast<Map<String, dynamic>>();
      } else {
        items = _list(data);
      }
      if (!mounted) return;
      setState(() => _activeWos = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingActive = false);
    }
  }

  Future<void> _loadReasonCodes() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConfig.manufacturingScrapReasonCodes);
      if (!mounted) return;
      setState(() => _reasonCodes = _list(res.data['data']));
    } catch (_) {}
  }

  Future<void> _lookup() async {
    final raw = _scanCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _looking = true;
      _wo = null;
      _jobCards = const [];
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.manufacturingWorkOrderByNumber(raw));
      final wo = (res.data['data'] as Map).cast<String, dynamic>();
      final id = wo['id'] as String;
      final jcRes = await api.get(ApiConfig.manufacturingWorkOrderJobCards(id));
      if (!mounted) return;
      setState(() {
        _wo = wo;
        _jobCards = _list(jcRes.data['data']);
      });
      _scanCtrl.clear();
      _scanFocus.requestFocus();
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 404
          ? 'Work order "$raw" not found'
          : (e.response?.data['message'] ?? e.message ?? 'Lookup failed');
      _toast(msg);
    } catch (e) {
      _toast('Lookup failed: $e');
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _openWo(Map<String, dynamic> wo) async {
    final number = wo['workOrderNumber'] as String?;
    if (number == null) return;
    _scanCtrl.text = number;
    await _lookup();
  }

  Future<void> _startJobCard(Map<String, dynamic> jc) async {
    try {
      await ref
          .read(apiClientProvider)
          .post(ApiConfig.manufacturingJobCardStart(jc['id'] as String));
      _toast('Started');
      await _refreshCurrentWo();
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<void> _completeJobCard(Map<String, dynamic> jc) async {
    final input = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CompleteJobCardSheet(),
    );
    if (input == null) return;
    try {
      await ref.read(apiClientProvider).post(
            ApiConfig.manufacturingJobCardComplete(jc['id'] as String),
            data: input,
          );
      _toast('Completed');
      await _refreshCurrentWo();
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<void> _logScrap(Map<String, dynamic> jc) async {
    if (_wo == null) return;
    final input = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LogScrapSheet(reasonCodes: _reasonCodes),
    );
    if (input == null) return;
    try {
      await ref.read(apiClientProvider).post(
            ApiConfig.manufacturingWorkOrderScrap(_wo!['id'] as String),
            data: {
              ...input,
              'jobCardId': jc['id'],
            },
          );
      _toast('Scrap logged');
      await _refreshCurrentWo();
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    }
  }

  Future<void> _refreshCurrentWo() async {
    if (_wo == null) return;
    final api = ref.read(apiClientProvider);
    try {
      final id = _wo!['id'] as String;
      final woRes = await api.get(ApiConfig.manufacturingWorkOrderById(id));
      final jcRes = await api.get(ApiConfig.manufacturingWorkOrderJobCards(id));
      if (!mounted) return;
      setState(() {
        _wo = (woRes.data['data'] as Map).cast<String, dynamic>();
        _jobCards = _list(jcRes.data['data']);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Floor'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadActiveWos();
              _refreshCurrentWo();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: TextField(
                controller: _scanCtrl,
                focusNode: _scanFocus,
                textInputAction: TextInputAction.go,
                decoration: InputDecoration(
                  labelText: 'Scan or enter WO number',
                  hintText: 'e.g. WO-00042',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.qr_code_scanner),
                  suffixIcon: _looking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _lookup,
                        ),
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\t\n\r]')),
                ],
                onSubmitted: (_) => _lookup(),
                style: KTypography.h3,
              ),
            ),
            Expanded(
              child: _wo != null ? _woView() : _activeWosView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeWosView() {
    if (_loadingActive) {
      return const Center(child: KLoading(message: 'Loading active orders...'));
    }
    if (_activeWos.isEmpty) {
      return const KEmptyState(
        icon: Icons.precision_manufacturing_outlined,
        title: 'No work orders in progress',
        subtitle: 'Scan a WO number above to start operations.',
      );
    }
    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: _activeWos.length,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (_, i) {
        final wo = _activeWos[i];
        final woNumber = wo['workOrderNumber']?.toString() ?? '';
        final priority = wo['priority']?.toString() ?? 'NORMAL';

        return KCard(
          onTap: () => _openWo(wo),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            woNumber,
                            style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          KSpacing.hGapSm,
                          KStatusChip(status: priority),
                        ],
                      ),
                      KSpacing.vGapXs,
                      Text(
                        'FG: ${wo['finishedGoodName'] ?? wo['finishedGoodId'] ?? ''} · Qty: ${wo['quantityToProduce']} (Done: ${wo['quantityProduced'] ?? 0})',
                        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: KColors.textHint),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _woView() {
    final wo = _wo!;
    final woNumber = wo['workOrderNumber']?.toString() ?? '';
    final status = wo['status']?.toString() ?? '';

    return RefreshIndicator(
      onRefresh: _refreshCurrentWo,
      child: ListView(
        padding: KSpacing.pagePadding,
        children: [
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        woNumber,
                        style: KTypography.mono(fontSize: 16, weight: FontWeight.w700),
                      ),
                      KStatusChip(status: status),
                    ],
                  ),
                  KSpacing.vGapSm,
                  Text(
                    'FG: ${wo['finishedGoodName'] ?? wo['finishedGoodId'] ?? ''} · Qty: ${wo['quantityToProduce']} (Produced: ${wo['quantityProduced'] ?? 0})',
                    style: KTypography.bodyMedium,
                  ),
                  if (wo['priority'] != null) ...[
                    KSpacing.vGapXs,
                    Text('Priority: ${wo['priority']}', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
          KSpacing.vGapMd,
          Text(
            'Job Cards (${_jobCards.length})',
            style: KTypography.h4,
          ),
          KSpacing.vGapSm,
          if (_jobCards.isEmpty)
            const KCard(
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md),
                child: Text(
                  'No job cards on this WO yet. Set up a routing in Manufacturing to generate them.',
                ),
              ),
            )
          else
            ..._jobCards.map(_jobCardCard),
          KSpacing.vGapMd,
          KButton.outlined(
            onPressed: () {
              setState(() {
                _wo = null;
                _jobCards = const [];
              });
              _scanFocus.requestFocus();
            },
            icon: Icons.arrow_back,
            label: 'Done — scan next WO',
          ),
        ],
      ),
    );
  }

  Widget _jobCardCard(Map<String, dynamic> jc) {
    final status = jc['status']?.toString() ?? 'PENDING';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${jc['sequenceNumber'] ?? '?'}. ${jc['operationName'] ?? jc['operationId'] ?? 'Operation'}',
                      style: KTypography.labelLarge,
                    ),
                  ),
                  KStatusChip(status: status),
                ],
              ),
              if (jc['workstationName'] != null) ...[
                KSpacing.vGapXs,
                Text(
                  'Workstation: ${jc['workstationName']}',
                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                ),
              ],
              KSpacing.vGapMd,
              Row(
                children: [
                  if (status == 'PENDING')
                    Expanded(
                      child: KButton.primary(
                        onPressed: () => _startJobCard(jc),
                        icon: Icons.play_arrow,
                        label: 'Start',
                      ),
                    ),
                  if (status == 'IN_PROGRESS') ...[
                    Expanded(
                      child: KButton.primary(
                        onPressed: () => _completeJobCard(jc),
                        icon: Icons.check,
                        label: 'Complete',
                      ),
                    ),
                    KSpacing.hGapSm,
                    Expanded(
                      child: KButton.danger(
                        onPressed: () => _logScrap(jc),
                        icon: Icons.delete_outline,
                        label: 'Scrap',
                      ),
                    ),
                  ],
                  if (status == 'COMPLETED')
                    Expanded(
                      child: KButton.outlined(
                        onPressed: () => _logScrap(jc),
                        icon: Icons.delete_outline,
                        label: 'Log Scrap',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompleteJobCardSheet extends StatefulWidget {
  @override
  State<_CompleteJobCardSheet> createState() => _CompleteJobCardSheetState();
}

class _CompleteJobCardSheetState extends State<_CompleteJobCardSheet> {
  final _qty = TextEditingController();
  final _hours = TextEditingController();
  final _notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Complete Job Card', style: KTypography.h3),
          KSpacing.vGapMd,
          TextField(
            controller: _qty,
            decoration: const InputDecoration(
              labelText: 'Quantity produced',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          KSpacing.vGapSm,
          TextField(
            controller: _hours,
            decoration: const InputDecoration(
              labelText: 'Actual hours (optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          KSpacing.vGapSm,
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          KSpacing.vGapMd,
          KButton.primary(
            onPressed: () => Navigator.pop(context, {
              if (_qty.text.trim().isNotEmpty)
                'quantityProduced': double.tryParse(_qty.text.trim()),
              if (_hours.text.trim().isNotEmpty)
                'actualHours': double.tryParse(_hours.text.trim()),
              if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
            }),
            label: 'Complete',
          ),
        ],
      ),
    );
  }
}

class _LogScrapSheet extends StatefulWidget {
  final List<Map<String, dynamic>> reasonCodes;
  const _LogScrapSheet({required this.reasonCodes});

  @override
  State<_LogScrapSheet> createState() => _LogScrapSheetState();
}

class _LogScrapSheetState extends State<_LogScrapSheet> {
  final _qty = TextEditingController();
  final _notes = TextEditingController();
  String? _reasonId;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Log Scrap', style: KTypography.h3),
          KSpacing.vGapMd,
          TextField(
            controller: _qty,
            decoration: const InputDecoration(
              labelText: 'Quantity scrapped',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          KSpacing.vGapSm,
          DropdownButtonFormField<String>(
            initialValue: _reasonId,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            items: widget.reasonCodes
                .map((r) => DropdownMenuItem<String>(
                      value: r['id'] as String,
                      child: Text('${r['code']} · ${r['name'] ?? ''}'),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _reasonId = v),
          ),
          KSpacing.vGapSm,
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          KSpacing.vGapMd,
          KButton.danger(
            onPressed: _qty.text.trim().isEmpty || _reasonId == null
                ? null
                : () => Navigator.pop(context, {
                      'quantity': double.tryParse(_qty.text.trim()),
                      'reasonCodeId': _reasonId,
                      if (_notes.text.trim().isNotEmpty)
                        'notes': _notes.text.trim(),
                    }),
            label: 'Save Scrap',
          ),
        ],
      ),
    );
  }
}
