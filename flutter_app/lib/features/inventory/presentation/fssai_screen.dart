import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// FSSAI / Food Safety compliance management. Three tabs:
///
///   1. Item compliance — paste an item id, declare veg/non-veg,
///      allergens, nutritional info, date-marking type, shelf life,
///      and the per-item FSSAI license.
///   2. Allergen exposure report — for incident response: enter an
///      allergen, see every item containing it.
///   3. License renewal — list of FSSAI licenses (org-level FBO +
///      future per-item) expiring within N days.
class FssaiScreen extends ConsumerStatefulWidget {
  const FssaiScreen({super.key});

  @override
  ConsumerState<FssaiScreen> createState() => _FssaiScreenState();
}

class _FssaiScreenState extends ConsumerState<FssaiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FSSAI Compliance'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Item compliance'),
            Tab(text: 'Allergen exposure'),
            Tab(text: 'License renewal'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ItemComplianceTab(),
          _AllergenExposureTab(),
          _LicenseRenewalTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: Item compliance ────────────────────────────────────────────────

class _ItemComplianceTab extends ConsumerStatefulWidget {
  const _ItemComplianceTab();

  @override
  ConsumerState<_ItemComplianceTab> createState() => _ItemComplianceTabState();
}

class _ItemComplianceTabState extends ConsumerState<_ItemComplianceTab> {
  final _itemCtl = TextEditingController();
  String? _itemId;

  @override
  void dispose() {
    _itemCtl.dispose();
    super.dispose();
  }

  void _load() {
    final id = _itemCtl.text.trim();
    if (id.isEmpty) return;
    setState(() => _itemId = id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _itemCtl,
                  decoration: const InputDecoration(
                    labelText: 'Item id',
                    helperText:
                        'The SKU whose FSSAI declarations you want to manage',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              FilledButton(onPressed: _load, child: const Text('Load')),
            ],
          ),
        ),
        Expanded(
          child: _itemId == null
              ? const Center(child: Text('Enter an item id to declare FSSAI fields'))
              : _ItemComplianceForm(itemId: _itemId!),
        ),
      ],
    );
  }
}

class _ItemComplianceForm extends ConsumerStatefulWidget {
  final String itemId;
  const _ItemComplianceForm({required this.itemId});

  @override
  ConsumerState<_ItemComplianceForm> createState() =>
      _ItemComplianceFormState();
}

class _ItemComplianceFormState extends ConsumerState<_ItemComplianceForm> {
  final _licenseCtl = TextEditingController();
  final _shelfLifeCtl = TextEditingController();
  String? _vegClass;
  String? _dateMarking;
  Set<String> _allergens = {};
  bool _loaded = false;

  @override
  void dispose() {
    _licenseCtl.dispose();
    _shelfLifeCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(apiClientProvider).put(
        ApiConfig.fssaiItem(widget.itemId),
        data: {
          'fssaiLicense': _licenseCtl.text.trim().isEmpty
              ? null
              : _licenseCtl.text.trim(),
          'vegClassification': _vegClass,
          'allergens': _allergens.toList(),
          'dateMarkingType': _dateMarking,
          'shelfLifeDays': int.tryParse(_shelfLifeCtl.text.trim()),
        },
      );
      messenger.showSnackBar(
          const SnackBar(content: Text('FSSAI compliance saved')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  Future<void> _printLabel() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Rendering FSSAI food label…')),
    );
    try {
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.fssaiFoodLabelPdf(widget.itemId),
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = res.data as List<int>;
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: 'food-label-${widget.itemId}.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(_itemFssaiProvider(widget.itemId));
    final allergensAsync = ref.watch(_majorAllergensProvider);

    return itemAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (item) {
        // One-shot population from server payload — user edits then save.
        if (!_loaded) {
          _licenseCtl.text = item['fssaiLicense']?.toString() ?? '';
          _shelfLifeCtl.text = item['shelfLifeDays']?.toString() ?? '';
          _vegClass = item['vegClassification']?.toString();
          _dateMarking = item['dateMarkingType']?.toString();
          final raw = item['allergens'];
          _allergens = raw is List
              ? raw.whereType<String>().toSet()
              : <String>{};
          _loaded = true;
        }

        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            Text('Item: ${item['name'] ?? widget.itemId}',
                style: KTypography.titleMedium),
            const SizedBox(height: KSpacing.md),
            TextField(
              controller: _licenseCtl,
              decoration: const InputDecoration(
                labelText: 'FSSAI license (14 digits)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: KSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _vegClass,
              decoration: const InputDecoration(
                labelText: 'Veg classification',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'VEGETARIAN',
                    child: Text('🟢 Vegetarian')),
                DropdownMenuItem(
                    value: 'NON_VEGETARIAN',
                    child: Text('🔴 Non-Vegetarian')),
                DropdownMenuItem(value: 'VEGAN', child: Text('🌱 Vegan')),
                DropdownMenuItem(value: 'EGG', child: Text('🟡 Egg')),
              ],
              onChanged: (v) => setState(() => _vegClass = v),
            ),
            const SizedBox(height: KSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _dateMarking,
              decoration: const InputDecoration(
                labelText: 'Date marking type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'BEST_BEFORE', child: Text('Best Before')),
                DropdownMenuItem(value: 'USE_BY', child: Text('Use By')),
                DropdownMenuItem(value: 'EXPIRY', child: Text('Expiry')),
              ],
              onChanged: (v) => setState(() => _dateMarking = v),
            ),
            const SizedBox(height: KSpacing.md),
            TextField(
              controller: _shelfLifeCtl,
              decoration: const InputDecoration(
                labelText: 'Shelf life (days)',
                helperText: 'MFG date + shelf life = expiry on a fresh batch',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: KSpacing.md),
            Text('Allergens declared on label', style: KTypography.titleSmall),
            const SizedBox(height: KSpacing.sm),
            allergensAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(ApiErrorParser.message(e)),
              data: (allergens) => Wrap(
                spacing: 6,
                runSpacing: 6,
                children: allergens.map((a) {
                  final selected = _allergens.contains(a);
                  return FilterChip(
                    label: Text(a.replaceAll('_', ' ')),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _allergens.add(a);
                        } else {
                          _allergens.remove(a);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: KSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save FSSAI declarations'),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _printLabel,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print food label'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Tab 2: Allergen exposure ──────────────────────────────────────────────

class _AllergenExposureTab extends ConsumerStatefulWidget {
  const _AllergenExposureTab();

  @override
  ConsumerState<_AllergenExposureTab> createState() =>
      _AllergenExposureTabState();
}

class _AllergenExposureTabState extends ConsumerState<_AllergenExposureTab> {
  String? _allergen;

  @override
  Widget build(BuildContext context) {
    final allergensAsync = ref.watch(_majorAllergensProvider);
    return Padding(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allergensAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(ApiErrorParser.message(e)),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _allergen,
              decoration: const InputDecoration(
                labelText: 'Allergen',
                helperText:
                    'Pick an allergen to find every item declaring it',
                border: OutlineInputBorder(),
              ),
              items: list
                  .map((a) => DropdownMenuItem(
                      value: a, child: Text(a.replaceAll('_', ' '))))
                  .toList(),
              onChanged: (v) => setState(() => _allergen = v),
            ),
          ),
          const SizedBox(height: KSpacing.md),
          Expanded(
            child: _allergen == null
                ? const Center(child: Text('Pick an allergen above'))
                : _ExposureList(allergen: _allergen!),
          ),
        ],
      ),
    );
  }
}

class _ExposureList extends ConsumerWidget {
  final String allergen;
  const _ExposureList({required this.allergen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_exposureProvider(allergen));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (items) {
        if (items.isEmpty) {
          return Center(
              child: Text('No items declare ${allergen.replaceAll('_', ' ')}'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final r = items[i];
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: Text(r['name']?.toString() ?? '—'),
                subtitle: Text('SKU: ${r['sku'] ?? '—'}\n'
                    'Allergens: ${(r['allergens'] as List?)?.join(", ") ?? '—'}'),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tab 3: License renewal ────────────────────────────────────────────────

class _LicenseRenewalTab extends ConsumerStatefulWidget {
  const _LicenseRenewalTab();

  @override
  ConsumerState<_LicenseRenewalTab> createState() =>
      _LicenseRenewalTabState();
}

class _LicenseRenewalTabState extends ConsumerState<_LicenseRenewalTab> {
  int _daysAhead = 60;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Horizon:'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _daysAhead,
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 days')),
                DropdownMenuItem(value: 60, child: Text('60 days')),
                DropdownMenuItem(value: 90, child: Text('90 days')),
                DropdownMenuItem(value: 180, child: Text('180 days')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _daysAhead = v);
              },
            ),
          ]),
          const SizedBox(height: KSpacing.md),
          Expanded(child: _RenewalList(daysAhead: _daysAhead)),
        ],
      ),
    );
  }
}

class _RenewalList extends ConsumerWidget {
  final int daysAhead;
  const _RenewalList({required this.daysAhead});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_renewalProvider(daysAhead));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return Center(
              child: Text('No FSSAI licenses expire within $daysAhead days'));
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            final days = r['daysToExpiry'];
            final urgent = days is int && days <= 30;
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              color: urgent ? Colors.red.shade50 : null,
              child: ListTile(
                leading: Icon(Icons.event_busy,
                    color: urgent ? Colors.red : Colors.orange),
                title: Text('${r['scope']} • ${r['license']}'),
                subtitle: Text(
                    'Expires ${r['expiryDate']} • $days days from today'),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final _majorAllergensProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.fssaiAllergens);
  final data = res.data['data'];
  return data is List ? data.whereType<String>().toList() : <String>[];
});

final _itemFssaiProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, itemId) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.fssaiItem(itemId));
  final data = res.data['data'];
  return data is Map<String, dynamic> ? data : <String, dynamic>{};
});

final _exposureProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, allergen) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.fssaiAllergenExposure,
      queryParameters: {'allergen': allergen});
  final data = res.data['data'];
  if (data is List) {
    return data
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
  return [];
});

final _renewalProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, daysAhead) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(ApiConfig.fssaiLicenseRenewal,
      queryParameters: {'daysAhead': daysAhead});
  final data = res.data['data'];
  if (data is List) {
    return data
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
  return [];
});
