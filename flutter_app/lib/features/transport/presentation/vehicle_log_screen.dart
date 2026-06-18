import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/transport_repository.dart';

/// Own-fleet running-cost ledger + per-vehicle TCO (₹/km, mileage). Filter by a
/// vehicle number to see its cost summary.
class VehicleLogScreen extends ConsumerStatefulWidget {
  const VehicleLogScreen({super.key});

  @override
  ConsumerState<VehicleLogScreen> createState() => _VehicleLogScreenState();
}

class _VehicleLogScreenState extends ConsumerState<VehicleLogScreen> {
  List<dynamic>? _logs;
  Map<String, dynamic>? _summary;
  String? _vehicleFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(transportRepositoryProvider);
      final logs = await repo.listVehicleLogs(vehicleNumber: _vehicleFilter);
      Map<String, dynamic>? summary;
      if (_vehicleFilter != null && _vehicleFilter!.isNotEmpty) {
        try {
          summary = await repo.vehicleSummary(_vehicleFilter!);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _summary = summary;
        _loading = false;
      });
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
      builder: (_) => _CreateVehicleLogSheet(prefillVehicle: _vehicleFilter),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Log'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Add entry'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  KCard(
                    child: KTextField(
                      label: 'Filter by vehicle number',
                      hint: 'e.g. MH12AB1234',
                      onChanged: (v) {
                        _vehicleFilter = v.trim().isEmpty ? null : v.trim();
                      },
                      onFieldSubmitted: (_) => _load(),
                    ),
                  ),
                  if (_summary != null) ...[
                    KSpacing.vGapMd,
                    _summaryCard(_summary!),
                  ],
                  KSpacing.vGapMd,
                  ...(_logs ?? const []).map(_logTile),
                  if ((_logs ?? const []).isEmpty)
                    KCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No entries yet.',
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

  Widget _summaryCard(Map<String, dynamic> s) {
    final perKm = (s['costPerKm'] as num?)?.toDouble() ?? 0;
    final mileage = (s['mileageKmPerLitre'] as num?)?.toDouble() ?? 0;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${s['vehicleNumber']} — cost of ownership',
              style: KTypography.titleSmall),
          KSpacing.vGapSm,
          Wrap(spacing: 16, runSpacing: 8, children: [
            _metric('Total spend',
                CurrencyFormatter.formatIndian(
                    (s['totalSpend'] as num?)?.toDouble() ?? 0)),
            _metric('Distance', '${(s['distanceKm'] as num?)?.toDouble() ?? 0} km'),
            _metric('Running cost',
                perKm > 0 ? '₹${perKm.toStringAsFixed(2)}/km' : '—'),
            _metric('Mileage',
                mileage > 0 ? '${mileage.toStringAsFixed(1)} km/L' : '—'),
          ]),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
          Text(value, style: KTypography.titleSmall),
        ],
      );

  Widget _logTile(dynamic l) {
    final type = l['logType'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: KCard(
        child: Row(
          children: [
            Icon(_iconFor(type), color: KColors.primary, size: 20),
            KSpacing.hGapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l['vehicleNumber']} · $type',
                      style: KTypography.bodyMedium),
                  Text(
                    '${l['logDate']}'
                    '${l['odometerKm'] != null ? ' · ${l['odometerKm']} km' : ''}'
                    '${l['quantity'] != null ? ' · ${l['quantity']} L' : ''}',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
                CurrencyFormatter.formatIndian(
                    (l['amount'] as num?)?.toDouble() ?? 0),
                style: KTypography.titleSmall),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'FUEL' => Icons.local_gas_station,
        'SERVICE' => Icons.build,
        'REPAIR' => Icons.handyman,
        'INSURANCE' => Icons.shield,
        'TYRE' => Icons.tire_repair,
        _ => Icons.directions_car,
      };
}

class _CreateVehicleLogSheet extends ConsumerStatefulWidget {
  final String? prefillVehicle;
  const _CreateVehicleLogSheet({this.prefillVehicle});

  @override
  ConsumerState<_CreateVehicleLogSheet> createState() =>
      _CreateVehicleLogSheetState();
}

class _CreateVehicleLogSheetState
    extends ConsumerState<_CreateVehicleLogSheet> {
  late final TextEditingController _vehicle =
      TextEditingController(text: widget.prefillVehicle ?? '');
  final _amount = TextEditingController();
  final _odo = TextEditingController();
  final _litres = TextEditingController();
  final _ref = TextEditingController();
  String _type = 'FUEL';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_vehicle, _amount, _odo, _litres, _ref]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_vehicle.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a vehicle number')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(transportRepositoryProvider).createVehicleLog({
        'vehicleNumber': _vehicle.text.trim(),
        'logType': _type,
        'logDate':
            '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
        'amount': double.tryParse(_amount.text.trim()) ?? 0,
        if (_odo.text.trim().isNotEmpty)
          'odometerKm': double.tryParse(_odo.text.trim()),
        if (_litres.text.trim().isNotEmpty)
          'quantity': double.tryParse(_litres.text.trim()),
        if (_ref.text.trim().isNotEmpty) 'referenceNo': _ref.text.trim(),
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
            Text('Add vehicle entry', style: KTypography.h3),
            KSpacing.vGapMd,
            KTextField(label: 'Vehicle number', controller: _vehicle),
            KSpacing.vGapSm,
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                  labelText: 'Type', border: OutlineInputBorder()),
              items: const [
                'FUEL', 'SERVICE', 'REPAIR', 'INSURANCE',
                'FITNESS', 'PERMIT', 'TYRE', 'OTHER',
              ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            KSpacing.vGapSm,
            Row(children: [
              Expanded(
                  child: KTextField(
                      label: 'Amount',
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true))),
              KSpacing.hGapSm,
              Expanded(
                  child: KTextField(
                      label: 'Odometer (km)',
                      controller: _odo,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true))),
            ]),
            KSpacing.vGapSm,
            Row(children: [
              Expanded(
                  child: KTextField(
                      label: 'Litres (fuel)',
                      controller: _litres,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true))),
              KSpacing.hGapSm,
              Expanded(
                  child: KTextField(label: 'Reference / bill no.', controller: _ref)),
            ]),
            KSpacing.vGapMd,
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(
                  '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today, size: 18),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            KSpacing.vGapMd,
            KButton(
              label: _saving ? 'Saving…' : 'Save entry',
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
