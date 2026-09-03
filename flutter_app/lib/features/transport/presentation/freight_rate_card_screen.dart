import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../data/transport_repository.dart';

/// Freight rate cards per transporter + lane + weight slab. These auto-fill the
/// freight on a new Lorry Receipt.
class FreightRateCardScreen extends ConsumerStatefulWidget {
  const FreightRateCardScreen({super.key});

  @override
  ConsumerState<FreightRateCardScreen> createState() =>
      _FreightRateCardScreenState();
}

class _FreightRateCardScreenState extends ConsumerState<FreightRateCardScreen> {
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
      final r = await ref.read(transportRepositoryProvider).listRateCards();
      if (mounted) setState(() { _items = r; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Load failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CreateRateCardSheet(),
    );
    if (created == true) await _load();
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(transportRepositoryProvider).deleteRateCard(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freight Rate Cards'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New rate'),
      ),
      body: _loading
          ? const Center(child: KLoading())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  KCard(
                    child: Text(
                      'A rate card auto-fills freight on a new Lorry Receipt for a '
                      'matching transporter, lane and weight slab.',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ),
                  KSpacing.vGapMd,
                  ...(_items ?? const []).map(_card),
                  if ((_items ?? const []).isEmpty)
                    KCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No rate cards yet.',
                            textAlign: TextAlign.center,
                            style: KTypography.bodyMedium
                                .copyWith(color: KColors.textSecondary)),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _card(dynamic c) {
    final rateType = c['rateType'] as String? ?? 'PER_KG';
    final rate = (c['rate'] as num?)?.toDouble() ?? 0;
    final unit = switch (rateType) {
      'FLAT' => 'flat',
      'PER_UNIT' => '/unit',
      _ => '/kg',
    };
    final slabMax = c['weightSlabMaxKg'];
    final slab = slabMax == null
        ? '${c['weightSlabMinKg']}kg+'
        : '${c['weightSlabMinKg']}–$slabMax kg';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c['origin']} → ${c['destination']} · ${c['mode']}',
                      style: KTypography.labelLarge),
                  KSpacing.vGapXs,
                  Text('${CurrencyFormatter.format(rate)} $unit · $slab'
                      '${(c['minCharge'] as num?) != null && (c['minCharge'] as num) > 0 ? ' · min ${CurrencyFormatter.format((c['minCharge'] as num).toDouble())}' : ''}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(c['id']?.toString() ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRateCardSheet extends ConsumerStatefulWidget {
  const _CreateRateCardSheet();

  @override
  ConsumerState<_CreateRateCardSheet> createState() =>
      _CreateRateCardSheetState();
}

class _CreateRateCardSheetState extends ConsumerState<_CreateRateCardSheet> {
  String? _transporterId;
  String _transporterName = '';
  final _origin = TextEditingController();
  final _dest = TextEditingController();
  final _rate = TextEditingController();
  final _minCharge = TextEditingController();
  final _slabMin = TextEditingController(text: '0');
  final _slabMax = TextEditingController();
  String _rateType = 'PER_KG';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_origin, _dest, _rate, _minCharge, _slabMin, _slabMax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTransporter() async {
    final c = await showContactPicker(context);
    if (c == null) return;
    setState(() {
      _transporterId = c['id']?.toString();
      _transporterName =
          c['displayName']?.toString() ?? c['name']?.toString() ?? '';
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
      await ref.read(transportRepositoryProvider).createRateCard({
        'transporterContactId': _transporterId,
        'origin': _origin.text.trim(),
        'destination': _dest.text.trim(),
        'mode': 'ROAD',
        'rateType': _rateType,
        'rate': double.tryParse(_rate.text.trim()) ?? 0,
        'minCharge': double.tryParse(_minCharge.text.trim()) ?? 0,
        'weightSlabMinKg': double.tryParse(_slabMin.text.trim()) ?? 0,
        if (_slabMax.text.trim().isNotEmpty)
          'weightSlabMaxKg': double.tryParse(_slabMax.text.trim()),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New rate card', style: KTypography.h3),
            KSpacing.vGapMd,
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Transporter'),
              subtitle: Text(_transporterName.isEmpty
                  ? 'Tap to pick a vendor'
                  : _transporterName),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTransporter,
            ),
            KSpacing.vGapSm,
            Row(children: [
              Expanded(child: KTextField(label: 'Origin', controller: _origin)),
              KSpacing.hGapSm,
              Expanded(child: KTextField(label: 'Destination', controller: _dest)),
            ]),
            KSpacing.vGapSm,
            DropdownButtonFormField<String>(
              initialValue: _rateType,
              decoration: const InputDecoration(
                  labelText: 'Rate type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'PER_KG', child: Text('Per kg')),
                DropdownMenuItem(value: 'FLAT', child: Text('Flat (per LR)')),
                DropdownMenuItem(value: 'PER_UNIT', child: Text('Per unit')),
              ],
              onChanged: (v) => setState(() => _rateType = v ?? _rateType),
            ),
            KSpacing.vGapSm,
            Row(children: [
              Expanded(
                  child: KTextField(
                      label: 'Rate',
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              KSpacing.hGapSm,
              Expanded(
                  child: KTextField(
                      label: 'Min charge',
                      controller: _minCharge,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            KSpacing.vGapSm,
            Row(children: [
              Expanded(
                  child: KTextField(
                      label: 'Slab min (kg)',
                      controller: _slabMin,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              KSpacing.hGapSm,
              Expanded(
                  child: KTextField(
                      label: 'Slab max (blank=∞)',
                      controller: _slabMax,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            KSpacing.vGapLg,
            KButton.primary(
              label: _saving ? 'Saving…' : 'Save rate card',
              icon: Icons.save,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
