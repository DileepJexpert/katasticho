import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Mobile-first shop-floor screen for production operators.
///
/// Operator flow:
///  1. Scan or type a WO number into the autofocused field (USB keyboard-
///     wedge scanners just type → Enter). Or pick from "Active work orders".
///  2. Tap a job card → big Start / Complete / Log Scrap buttons.
///
/// Designed so every interaction is one or two taps and works with a finger
/// in gloves on a 5" phone. No popovers, no nested forms.
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
      // Endpoint returns a Page envelope: data: { content: [...] }
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
      // non-fatal
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
    } catch (_) {
      // non-fatal
    }
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
      // Job cards live on a separate endpoint.
      final id = wo['id'] as String;
      final jcRes = await api.get(ApiConfig.manufacturingWorkOrderJobCards(id));
      if (!mounted) return;
      setState(() {
        _wo = wo;
        _jobCards = _list(jcRes.data['data']);
      });
      // Clear so the next scan refocuses the input.
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
        title: const Text('Shop floor'),
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
              padding: const EdgeInsets.all(12),
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
                  // Avoid weirdness from scanners that prepend tab/newline.
                  FilteringTextInputFormatter.deny(RegExp(r'[\t\n\r]')),
                ],
                onSubmitted: (_) => _lookup(),
                style: Theme.of(context).textTheme.titleLarge,
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_activeWos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No work orders in progress.\nScan a WO above to start.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _activeWos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final wo = _activeWos[i];
        return Card(
          child: ListTile(
            title: Text(
              '${wo['workOrderNumber']} · ${wo['priority'] ?? 'NORMAL'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              'FG ${wo['finishedGoodName'] ?? wo['finishedGoodId'] ?? ''} · '
              'qty ${wo['quantityToProduce']} '
              '(produced ${wo['quantityProduced'] ?? 0})',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openWo(wo),
          ),
        );
      },
    );
  }

  Widget _woView() {
    final wo = _wo!;
    return RefreshIndicator(
      onRefresh: _refreshCurrentWo,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        wo['workOrderNumber']?.toString() ?? '',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      _statusPill(wo['status']),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'FG ${wo['finishedGoodName'] ?? wo['finishedGoodId'] ?? ''} · '
                    'qty ${wo['quantityToProduce']} (produced ${wo['quantityProduced'] ?? 0})',
                  ),
                  if (wo['priority'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Priority: ${wo['priority']}'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Job cards (${_jobCards.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          if (_jobCards.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No job cards on this WO yet. '
                  'Set up a routing in Manufacturing to generate them.',
                ),
              ),
            )
          else
            ..._jobCards.map(_jobCardCard),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _wo = null;
                _jobCards = const [];
              });
              _scanFocus.requestFocus();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Done — scan next WO'),
          ),
        ],
      ),
    );
  }

  Widget _jobCardCard(Map<String, dynamic> jc) {
    final status = jc['status']?.toString() ?? 'PENDING';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${jc['sequenceNumber'] ?? '?'}. '
                    '${jc['operationName'] ?? jc['operationId'] ?? 'Operation'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _statusPill(status),
              ],
            ),
            if (jc['workstationName'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Workstation: ${jc['workstationName']}'),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == 'PENDING')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _startJobCard(jc),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start'),
                    ),
                  ),
                if (status == 'IN_PROGRESS') ...[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _completeJobCard(jc),
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _logScrap(jc),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Scrap'),
                    ),
                  ),
                ],
                if (status == 'COMPLETED')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _logScrap(jc),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Log scrap'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(Object? status) {
    final color = switch (status) {
      'PENDING' => Colors.blueGrey,
      'DRAFT' => Colors.blueGrey,
      'IN_PROGRESS' => Colors.orange,
      'COMPLETED' => Colors.green,
      'CANCELLED' => Colors.grey,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status?.toString() ?? '',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
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
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Complete job card',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            decoration: const InputDecoration(
              labelText: 'Quantity produced',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hours,
            decoration: const InputDecoration(
              labelText: 'Actual hours (optional)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              if (_qty.text.trim().isNotEmpty)
                'quantityProduced': double.tryParse(_qty.text.trim()),
              if (_hours.text.trim().isNotEmpty)
                'actualHours': double.tryParse(_hours.text.trim()),
              if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
            }),
            child: const Text('Complete'),
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
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Log scrap',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _qty,
            decoration: const InputDecoration(
              labelText: 'Quantity scrapped',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _qty.text.trim().isEmpty || _reasonId == null
                ? null
                : () => Navigator.pop(context, {
                      'quantity': double.tryParse(_qty.text.trim()),
                      'reasonCodeId': _reasonId,
                      if (_notes.text.trim().isNotEmpty)
                        'notes': _notes.text.trim(),
                    }),
            child: const Text('Save scrap'),
          ),
        ],
      ),
    );
  }
}
