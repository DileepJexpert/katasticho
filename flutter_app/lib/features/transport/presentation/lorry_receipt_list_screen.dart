import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../data/transport_repository.dart';

/// Lorry Receipts (consignment notes) for road/GTA freight. From a delivered LR
/// whose freight we bear, one tap raises a DRAFT purchase bill to the transporter.
class LorryReceiptListScreen extends ConsumerStatefulWidget {
  const LorryReceiptListScreen({super.key});

  @override
  ConsumerState<LorryReceiptListScreen> createState() =>
      _LorryReceiptListScreenState();
}

class _LorryReceiptListScreenState extends ConsumerState<LorryReceiptListScreen> {
  List<dynamic>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(transportRepositoryProvider).listLorryReceipts();
      if (mounted) setState(() { _items = r; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Load failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const _CreateLorryReceiptScreen()));
    if (created == true) await _load();
  }

  Future<void> _act(String id, Future<dynamic> Function() op, String ok) async {
    try {
      await op();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ok)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lorry Receipts'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New LR'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  ...(_items ?? const []).map(_lrCard),
                  if ((_items ?? const []).isEmpty)
                    KCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No lorry receipts yet. Tap "New LR" to create one.',
                          textAlign: TextAlign.center,
                          style: KTypography.bodyMedium
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _lrCard(dynamic lr) {
    final status = lr['status'] as String? ?? '';
    final basis = lr['freightBasis'] as String? ?? '';
    final billed = lr['freightBillId'] != null;
    final billable = (basis == 'PAID' || basis == 'TO_BE_BILLED') && !billed;
    final id = lr['id']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${lr['lrNumber']} · ${lr['lrDate']}',
                      style: KTypography.labelLarge),
                ),
                _statusChip(status),
              ],
            ),
            KSpacing.vGapXs,
            if (lr['origin'] != null)
              Text('${lr['origin']} → ${lr['destination']}'
                  '${lr['vehicleNumber'] != null ? ' · ${lr['vehicleNumber']}' : ''}',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
            KSpacing.vGapSm,
            Row(
              children: [
                Text('Freight: ',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
                Text(
                  CurrencyFormatter.formatIndian(
                      (lr['freightAmount'] as num?)?.toDouble() ?? 0),
                  style: KTypography.bodyMedium,
                ),
                KSpacing.hGapSm,
                _pill(basis, KColors.textSecondary),
                if ((lr['gstTreatment'] as String?) == 'RCM') ...[
                  KSpacing.hGapXs,
                  _pill('RCM', KColors.warning),
                ],
                if (billed) ...[
                  KSpacing.hGapXs,
                  _pill('Billed', KColors.success),
                ],
              ],
            ),
            KSpacing.vGapSm,
            Wrap(
              spacing: 8,
              children: [
                if (status == 'DRAFT')
                  OutlinedButton(
                      onPressed: () => _act(id,
                          () => ref.read(transportRepositoryProvider).issueLr(id),
                          'LR issued'),
                      child: const Text('Issue')),
                if (status == 'ISSUED')
                  OutlinedButton(
                      onPressed: () => _act(id,
                          () => ref.read(transportRepositoryProvider).deliverLr(id),
                          'Marked delivered'),
                      child: const Text('Deliver')),
                if (billable)
                  FilledButton.icon(
                    onPressed: () => _act(
                        id,
                        () => ref.read(transportRepositoryProvider).billFreight(id),
                        'Draft freight bill raised'),
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Bill freight'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'DELIVERED' => KColors.success,
      'CANCELLED' => KColors.textSecondary,
      'ISSUED' => KColors.warning,
      _ => KColors.textSecondary,
    };
    return _pill(status, color);
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: KTypography.bodySmall.copyWith(color: color)),
      );
}

/// Minimal LR create form — transporter (vendor) + route + freight + basis/GST.
class _CreateLorryReceiptScreen extends ConsumerStatefulWidget {
  const _CreateLorryReceiptScreen();

  @override
  ConsumerState<_CreateLorryReceiptScreen> createState() =>
      _CreateLorryReceiptScreenState();
}

class _CreateLorryReceiptScreenState
    extends ConsumerState<_CreateLorryReceiptScreen> {
  String? _transporterId;
  String _transporterName = '';
  final _origin = TextEditingController();
  final _dest = TextEditingController();
  final _vehicle = TextEditingController();
  final _weight = TextEditingController();
  final _freight = TextEditingController();
  String _basis = 'TO_BE_BILLED';
  String _gst = 'RCM';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_origin, _dest, _vehicle, _weight, _freight]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTransporter() async {
    final c = await showContactPicker(context);
    if (c == null) return;
    setState(() {
      _transporterId = c['id']?.toString();
      _transporterName = c['displayName']?.toString() ?? c['name']?.toString() ?? '';
    });
  }

  Future<void> _save() async {
    if (_transporterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a transporter')));
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await ref.read(transportRepositoryProvider).createLorryReceipt({
        'lrDate':
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'transporterContactId': _transporterId,
        'vehicleNumber': _vehicle.text.trim(),
        'origin': _origin.text.trim(),
        'destination': _dest.text.trim(),
        'mode': 'ROAD',
        'weightKg': double.tryParse(_weight.text.trim()),
        // Leave freight null to auto-fill from a rate card; explicit value wins.
        if (_freight.text.trim().isNotEmpty)
          'freightAmount': double.tryParse(_freight.text.trim()),
        'freightBasis': _basis,
        'gstTreatment': _gst,
        'freightGstRate': 5,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: ${e.toString().replaceAll('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Lorry Receipt')),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Transporter'),
                  subtitle: Text(_transporterName.isEmpty
                      ? 'Tap to pick a vendor'
                      : _transporterName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickTransporter,
                ),
                const Divider(),
                KSpacing.vGapSm,
                Row(children: [
                  Expanded(child: KTextField(label: 'Origin', controller: _origin)),
                  KSpacing.hGapSm,
                  Expanded(child: KTextField(label: 'Destination', controller: _dest)),
                ]),
                KSpacing.vGapSm,
                KTextField(label: 'Vehicle number', controller: _vehicle),
                KSpacing.vGapSm,
                Row(children: [
                  Expanded(
                      child: KTextField(
                          label: 'Weight (kg)',
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                  KSpacing.hGapSm,
                  Expanded(
                      child: KTextField(
                          label: 'Freight (blank = rate card)',
                          controller: _freight,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                ]),
              ],
            ),
          ),
          KSpacing.vGapMd,
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Freight terms', style: KTypography.labelLarge),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  initialValue: _basis,
                  decoration: const InputDecoration(
                      labelText: 'Payment basis', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'TO_BE_BILLED',
                        child: Text('To be billed (transporter bills us)')),
                    DropdownMenuItem(
                        value: 'PAID', child: Text('Paid (we paid at booking)')),
                    DropdownMenuItem(
                        value: 'TO_PAY',
                        child: Text('To pay (consignee pays)')),
                  ],
                  onChanged: (v) => setState(() => _basis = v ?? _basis),
                ),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  initialValue: _gst,
                  decoration: const InputDecoration(
                      labelText: 'GST treatment', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'RCM', child: Text('RCM (GTA reverse charge 5%)')),
                    DropdownMenuItem(value: 'FORWARD', child: Text('Forward charge')),
                    DropdownMenuItem(value: 'EXEMPT', child: Text('Exempt')),
                  ],
                  onChanged: (v) => setState(() => _gst = v ?? _gst),
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,
          KButton(
            label: _saving ? 'Saving…' : 'Save LR',
            icon: Icons.save,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
