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
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';

/// FSSAI / Food Safety compliance management. Three tabs:
///
///   1. Item compliance — select / search item, declare veg/non-veg,
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
        title: const Text('FSSAI Food Safety Compliance'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Item Compliance'),
            Tab(text: 'Allergen Exposure'),
            Tab(text: 'License Renewals'),
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
          padding: KSpacing.pagePadding,
          child: Row(
            children: [
              Expanded(
                child: KTextField(
                  controller: _itemCtl,
                  label: 'Item Identifier / SKU',
                  hint: 'Enter Catalog Item ID or SKU to manage FSSAI declarations',
                  prefixIcon: Icons.inventory_2_outlined,
                  onFieldSubmitted: (_) => _load(),
                ),
              ),
              KSpacing.hGapSm,
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: KButton.primary(
                  label: 'Load SKU',
                  icon: Icons.search,
                  onPressed: _load,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _itemId == null
              ? const KEmptyState(
                  icon: Icons.restaurant_outlined,
                  title: 'Declare Food Safety Compliance',
                  subtitle: 'Enter an item SKU above to configure FSSAI license numbers, veg classifications, allergens, and shelf life parameters.',
                )
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
          const SnackBar(content: Text('FSSAI compliance saved successfully')));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  Future<void> _printLabel() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Generating compliant FSSAI food label PDF…')),
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
      loading: () => const Center(child: KLoading(message: 'Loading FSSAI declarations...')),
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
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(KSpacing.sm),
                        decoration: BoxDecoration(
                          color: KColors.primary.withValues(alpha: 0.12),
                          borderRadius: KSpacing.borderRadiusSm,
                        ),
                        child: const Icon(Icons.verified_outlined, color: KColors.primary, size: 24),
                      ),
                      KSpacing.hGapMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'] ?? widget.itemId, style: KTypography.titleMedium),
                            KSpacing.vGapXs,
                            Text(
                              'FSSAI Regulatory & Labeling Compliance Profile',
                              style: KTypography.caption.copyWith(color: KColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  KTextField(
                    controller: _licenseCtl,
                    label: 'FSSAI 14-Digit License Number',
                    hint: 'e.g. 10019022009876',
                    keyboardType: TextInputType.number,
                  ),
                  KSpacing.vGapSm,
                  KCompactRow(children: [
                    DropdownButtonFormField<String>(
                      initialValue: _vegClass,
                      decoration: const InputDecoration(
                        labelText: 'Veg Classification',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'VEGETARIAN', child: Text('🟢 Vegetarian')),
                        DropdownMenuItem(value: 'NON_VEGETARIAN', child: Text('🔴 Non-Vegetarian')),
                        DropdownMenuItem(value: 'VEGAN', child: Text('🌱 Vegan')),
                        DropdownMenuItem(value: 'EGG', child: Text('🟡 Contains Egg')),
                      ],
                      onChanged: (v) => setState(() => _vegClass = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _dateMarking,
                      decoration: const InputDecoration(
                        labelText: 'Date Marking Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'BEST_BEFORE', child: Text('Best Before')),
                        DropdownMenuItem(value: 'USE_BY', child: Text('Use By')),
                        DropdownMenuItem(value: 'EXPIRY', child: Text('Expiry Date')),
                      ],
                      onChanged: (v) => setState(() => _dateMarking = v),
                    ),
                  ]),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: _shelfLifeCtl,
                    label: 'Shelf Life (Days from Mfg Date)',
                    hint: 'e.g. 180 (automatically calculates batch expiry date)',
                    keyboardType: TextInputType.number,
                  ),
                  KSpacing.vGapMd,
                  Text('Allergens Declared on Packaging', style: KTypography.titleSmall),
                  KSpacing.vGapSm,
                  allergensAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text(ApiErrorParser.message(e)),
                    data: (allergens) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                  KSpacing.vGapLg,
                  Row(
                    children: [
                      Expanded(
                        child: KButton.primary(
                          onPressed: _save,
                          icon: Icons.save,
                          label: 'Save FSSAI Compliance',
                        ),
                      ),
                      KSpacing.hGapSm,
                      KButton.outlined(
                        onPressed: _printLabel,
                        icon: Icons.print_outlined,
                        label: 'Print Food Label',
                      ),
                    ],
                  ),
                ],
              ),
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
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          allergensAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(ApiErrorParser.message(e)),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _allergen,
              decoration: const InputDecoration(
                labelText: 'Select Specific Allergen',
                helperText:
                    'Audit all stock keeping units and finished batches declaring this allergen',
                border: OutlineInputBorder(),
              ),
              items: list
                  .map((a) => DropdownMenuItem(
                      value: a, child: Text(a.replaceAll('_', ' '))))
                  .toList(),
              onChanged: (v) => setState(() => _allergen = v),
            ),
          ),
          KSpacing.vGapMd,
          Expanded(
            child: _allergen == null
                ? const KEmptyState(
                    icon: Icons.warning_amber_rounded,
                    title: 'Select an Allergen',
                    subtitle: 'Choose an allergen from the dropdown above to view an immediate exposure and contamination audit.',
                  )
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
      loading: () => const Center(child: KLoading(message: 'Auditing allergen exposure...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (items) {
        if (items.isEmpty) {
          return KEmptyState(
            icon: Icons.check_circle_outline,
            title: 'No Exposed Items Found',
            subtitle: 'No inventory items currently declare ${allergen.replaceAll('_', ' ')}.',
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => KSpacing.vGapSm,
          itemBuilder: (ctx, i) {
            final r = items[i];
            return KCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(KSpacing.sm),
                    decoration: BoxDecoration(
                      color: KColors.warning.withValues(alpha: 0.12),
                      borderRadius: KSpacing.borderRadiusSm,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: KColors.warning, size: 24),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['name']?.toString() ?? '—', style: KTypography.titleMedium),
                        KSpacing.vGapXs,
                        Row(
                          children: [
                            Text('SKU: ', style: KTypography.caption),
                            Text(
                              r['sku']?.toString() ?? '—',
                              style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (r['allergens'] != null) ...[
                          KSpacing.vGapXs,
                          Text(
                            'Allergens: ${(r['allergens'] as List?)?.join(", ") ?? '—'}',
                            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
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
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Expiry Horizon:', style: KTypography.labelMedium),
              KSpacing.hGapSm,
              DropdownButton<int>(
                value: _daysAhead,
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 Days')),
                  DropdownMenuItem(value: 60, child: Text('60 Days')),
                  DropdownMenuItem(value: 90, child: Text('90 Days')),
                  DropdownMenuItem(value: 180, child: Text('180 Days')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _daysAhead = v);
                },
              ),
            ],
          ),
          KSpacing.vGapMd,
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
      loading: () => const Center(child: KLoading(message: 'Checking license expiries...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return KEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'All Licenses Active & Compliant',
            subtitle: 'No FSSAI food business licenses are due to expire within the next $daysAhead days.',
          );
        }
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => KSpacing.vGapSm,
          itemBuilder: (ctx, i) {
            final r = rows[i];
            final days = r['daysToExpiry'];
            final urgent = days is int && days <= 30;
            return KCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(KSpacing.sm),
                    decoration: BoxDecoration(
                      color: (urgent ? KColors.error : KColors.warning).withValues(alpha: 0.12),
                      borderRadius: KSpacing.borderRadiusSm,
                    ),
                    child: Icon(
                      Icons.event_busy,
                      color: urgent ? KColors.error : KColors.warning,
                      size: 24,
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              r['scope']?.toString() ?? 'FBO License',
                              style: KTypography.titleMedium,
                            ),
                            KSpacing.hGapSm,
                            KStatusChip(status: urgent ? 'EXPIRING_SOON' : 'ACTIVE'),
                          ],
                        ),
                        KSpacing.vGapXs,
                        Row(
                          children: [
                            Text('License: ', style: KTypography.caption),
                            Text(
                              r['license']?.toString() ?? '—',
                              style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        KSpacing.vGapXs,
                        Text(
                          'Expires on ${r['expiryDate']} ($days days remaining)',
                          style: KTypography.bodySmall.copyWith(
                            color: urgent ? KColors.error : KColors.textSecondary,
                            fontWeight: urgent ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
