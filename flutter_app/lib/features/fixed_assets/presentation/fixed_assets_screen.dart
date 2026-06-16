import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';

class FixedAssetsScreen extends ConsumerStatefulWidget {
  const FixedAssetsScreen({super.key});

  @override
  ConsumerState<FixedAssetsScreen> createState() => _FixedAssetsScreenState();
}

class _FixedAssetsScreenState extends ConsumerState<FixedAssetsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fixed Assets'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Assets'),
              Tab(text: 'Income-Tax Schedule'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AssetsTab(),
            _IncomeTaxScheduleTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── helpers ────────────────────────────────────────

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _dioMessage(Object e, String fallback) {
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['message'] != null) return body['message'].toString();
  }
  return fallback;
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

// ─────────────────────────── Assets tab ─────────────────────────────────────

class _AssetsTab extends ConsumerStatefulWidget {
  const _AssetsTab();

  @override
  ConsumerState<_AssetsTab> createState() => _AssetsTabState();
}

class _AssetsTabState extends ConsumerState<_AssetsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _assets = [];
  late DateTime _period;
  bool _runningDepreciation = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTime(now.year, now.month);
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.fixedAssets);
      final data = res.data['data'];
      _assets = (data is List ? data : const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      _error = _dioMessage(e, 'Failed to load fixed assets');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _period,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12),
      helpText: 'Select depreciation month',
    );
    if (picked != null && mounted) {
      setState(() => _period = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _runDepreciation() async {
    setState(() => _runningDepreciation = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        ApiConfig.fixedAssetDepreciationRun,
        queryParameters: {'year': _period.year, 'month': _period.month},
      );
      final data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final count = data['assetCount'] ?? 0;
      final total = _toDouble(data['totalDepreciation']);
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Posted depreciation for $count asset(s): ${CurrencyFormatter.formatIndian(total)}'),
      ));
      await _fetch();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(_dioMessage(e, 'Could not run depreciation'))));
    } finally {
      if (mounted) setState(() => _runningDepreciation = false);
    }
  }

  Future<void> _openAsset(String id) async {
    Map<String, dynamic>? detail;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.fixedAssetById(id));
      detail = (res.data['data'] as Map?)?.cast<String, dynamic>();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_dioMessage(e, 'Could not load asset'))));
      return;
    }
    if (detail == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssetDetailSheet(
        detail: detail!,
        onDisposed: _fetch,
      ),
    );
  }

  Future<void> _addAsset() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AssetForm(),
    );
    if (created == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _toolbar(),
          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAsset,
        icon: const Icon(Icons.add),
        label: const Text('Add asset'),
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: KSpacing.pagePadding,
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _pickPeriod,
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text(
                '${_monthName(_period.month)} ${_period.year}'),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: KButton(
              label: _runningDepreciation ? 'Running…' : 'Run depreciation',
              icon: Icons.play_arrow,
              isLoading: _runningDepreciation,
              onPressed: _runDepreciation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return KErrorView(message: _error!, onRetry: _fetch);
    }
    if (_assets.isEmpty) {
      return const KEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No fixed assets',
        subtitle: 'Add your first asset to start tracking depreciation.',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: _assets.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (context, i) {
          final a = _assets[i];
          return _AssetCard(
            asset: a,
            onTap: () {
              final id = a['id']?.toString();
              if (id != null) _openAsset(id);
            },
          );
        },
      ),
    );
  }
}

String _monthName(int m) {
  const names = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return (m >= 1 && m <= 12) ? names[m] : '$m';
}

class _AssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onTap;

  const _AssetCard({required this.asset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = asset['name']?.toString() ?? '--';
    final code = asset['assetCode']?.toString();
    final cost = _toDouble(asset['cost']);
    final accumulated = _toDouble(asset['accumulatedDepreciation']);
    final bookValue = cost - accumulated;
    final method = asset['bookMethod']?.toString() ?? '';
    final status = asset['status']?.toString() ?? 'ACTIVE';
    final disposed = status == 'DISPOSED';
    final statusColor = disposed ? KColors.textSecondary : KColors.success;

    return KCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Text(
                  [
                    if (code != null && code.isNotEmpty) code,
                    if (method.isNotEmpty) method,
                  ].join(' · '),
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
                KSpacing.vGapXs,
                Text(
                  'Cost ${CurrencyFormatter.formatIndian(cost)} · '
                  'Book value ${CurrencyFormatter.formatIndian(bookValue)}',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
              ],
            ),
          ),
          KSpacing.hGapSm,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              disposed ? 'Disposed' : 'Active',
              style: KTypography.labelSmall.copyWith(color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Asset detail bottom sheet ──────────────────────────

class _AssetDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> detail;
  final VoidCallback onDisposed;

  const _AssetDetailSheet({required this.detail, required this.onDisposed});

  @override
  ConsumerState<_AssetDetailSheet> createState() => _AssetDetailSheetState();
}

class _AssetDetailSheetState extends ConsumerState<_AssetDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final asset =
        (widget.detail['asset'] as Map?)?.cast<String, dynamic>() ?? {};
    final bookValue = _toDouble(widget.detail['bookValue']);
    final schedule = (widget.detail['schedule'] as List?) ?? const [];
    final status = asset['status']?.toString() ?? 'ACTIVE';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: KSpacing.pagePadding,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(asset['name']?.toString() ?? '--',
                      style: KTypography.h3),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            KSpacing.vGapSm,
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kv('Asset code', asset['assetCode']?.toString() ?? '--'),
                  _kv('Category', asset['category']?.toString() ?? '--'),
                  _kv('Acquired', asset['acquisitionDate']?.toString() ?? '--'),
                  _kv('Cost',
                      CurrencyFormatter.formatIndian(_toDouble(asset['cost']))),
                  _kv(
                      'Residual value',
                      CurrencyFormatter.formatIndian(
                          _toDouble(asset['residualValue']))),
                  _kv('Book method', asset['bookMethod']?.toString() ?? '--'),
                  _kv(
                      'Accumulated depreciation',
                      CurrencyFormatter.formatIndian(
                          _toDouble(asset['accumulatedDepreciation']))),
                  _kv('Book value', CurrencyFormatter.formatIndian(bookValue),
                      highlight: true),
                  _kv('IT block', asset['itBlock']?.toString() ?? '--'),
                  _kv('IT rate %', '${asset['itRatePct'] ?? '--'}'),
                ],
              ),
            ),
            if (status == 'ACTIVE') ...[
              KSpacing.vGapSm,
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: KColors.error),
                  onPressed: () => _disposeDialog(asset),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Dispose asset'),
                ),
              ),
            ],
            KSpacing.vGapLg,
            Text('Depreciation history', style: KTypography.h3),
            KSpacing.vGapSm,
            if (schedule.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No depreciation posted yet',
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.textHint)),
              )
            else
              ...schedule.map((raw) {
                final s = Map<String, dynamic>.from(raw as Map);
                final year = s['periodYear'];
                final month = (s['periodMonth'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: KCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_monthName(month)} $year',
                                  style: KTypography.labelLarge),
                              KSpacing.vGapXs,
                              Text(
                                'Opening ${CurrencyFormatter.formatIndian(_toDouble(s['openingWdv']))} · '
                                'Closing ${CurrencyFormatter.formatIndian(_toDouble(s['closingWdv']))}',
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatIndian(
                              _toDouble(s['depreciationAmount'])),
                          style: KTypography.labelLarge
                              .copyWith(color: KColors.primary),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _kv(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: KTypography.bodyMedium
                  .copyWith(color: KColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: highlight
                  ? KTypography.labelLarge.copyWith(color: KColors.primary)
                  : KTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _disposeDialog(Map<String, dynamic> asset) async {
    final id = asset['id']?.toString();
    if (id == null) return;
    DateTime disposalDate = DateTime.now();
    final proceedsCtrl = TextEditingController(text: '0');
    final proceedsAccCtrl = TextEditingController(text: '1010');
    final gainLossAccCtrl = TextEditingController(text: '4900');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Dispose asset'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disposal date'),
                  subtitle: Text(_isoDate(disposalDate)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: disposalDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setLocal(() => disposalDate = picked);
                  },
                ),
                TextField(
                  controller: proceedsCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Proceeds',
                    border: OutlineInputBorder(),
                  ),
                ),
                KSpacing.vGapMd,
                TextField(
                  controller: proceedsAccCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Proceeds account code',
                    border: OutlineInputBorder(),
                  ),
                ),
                KSpacing.vGapMd,
                TextField(
                  controller: gainLossAccCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Gain/Loss account code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Dispose')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        ApiConfig.fixedAssetDispose(id),
        data: {
          'disposalDate': _isoDate(disposalDate),
          'proceeds': double.tryParse(proceedsCtrl.text.trim()) ?? 0,
          'proceedsAccountCode': proceedsAccCtrl.text.trim(),
          'gainLossAccountCode': gainLossAccCtrl.text.trim(),
        },
      );
      final data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final gainLoss = _toDouble(data['gainLoss']);
      final label = gainLoss >= 0 ? 'Gain' : 'Loss';
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Asset disposed. $label on disposal: ${CurrencyFormatter.formatIndian(gainLoss.abs())}'),
      ));
      if (navigator.canPop()) navigator.pop();
      widget.onDisposed();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(_dioMessage(e, 'Could not dispose asset'))));
    }
  }
}

// ─────────────────────────── Add-asset form ─────────────────────────────────

class _AssetForm extends ConsumerStatefulWidget {
  const _AssetForm();

  @override
  ConsumerState<_AssetForm> createState() => _AssetFormState();
}

class _AssetFormState extends ConsumerState<_AssetForm> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _residualCtrl = TextEditingController(text: '0');
  final _usefulLifeCtrl = TextEditingController();
  final _bookRateCtrl = TextEditingController();
  final _itBlockCtrl = TextEditingController();
  final _itRateCtrl = TextEditingController();

  DateTime _acquisitionDate = DateTime.now();
  String _bookMethod = 'SLM';
  bool _saving = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _costCtrl.dispose();
    _residualCtrl.dispose();
    _usefulLifeCtrl.dispose();
    _bookRateCtrl.dispose();
    _itBlockCtrl.dispose();
    _itRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _costCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name and cost are required')));
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'assetCode': _codeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'category': _categoryCtrl.text.trim(),
        'acquisitionDate': _isoDate(_acquisitionDate),
        'cost': double.tryParse(_costCtrl.text.trim()) ?? 0,
        'residualValue': double.tryParse(_residualCtrl.text.trim()) ?? 0,
        'bookMethod': _bookMethod,
        'itBlock': _itBlockCtrl.text.trim(),
        'itRatePct': double.tryParse(_itRateCtrl.text.trim()),
      };
      if (_bookMethod == 'SLM') {
        body['bookUsefulLifeMonths'] =
            int.tryParse(_usefulLifeCtrl.text.trim());
      } else {
        body['bookRatePct'] = double.tryParse(_bookRateCtrl.text.trim());
      }
      await api.post(ApiConfig.fixedAssets, data: body);
      messenger
          .showSnackBar(const SnackBar(content: Text('Asset created')));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(_dioMessage(e, 'Could not create asset'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: KSpacing.pagePadding,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Add asset', style: KTypography.h3)),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              KSpacing.vGapMd,
              _field(_codeCtrl, 'Asset code'),
              KSpacing.vGapMd,
              _field(_nameCtrl, 'Name'),
              KSpacing.vGapMd,
              _field(_categoryCtrl, 'Category'),
              KSpacing.vGapMd,
              ListTile(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(color: KColors.divider),
                ),
                title: const Text('Acquisition date'),
                subtitle: Text(_isoDate(_acquisitionDate)),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _acquisitionDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _acquisitionDate = picked);
                  }
                },
              ),
              KSpacing.vGapMd,
              _field(_costCtrl, 'Cost', number: true),
              KSpacing.vGapMd,
              _field(_residualCtrl, 'Residual value', number: true),
              KSpacing.vGapMd,
              DropdownButtonFormField<String>(
                initialValue: _bookMethod,
                decoration: const InputDecoration(
                  labelText: 'Book method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'SLM', child: Text('SLM (straight line)')),
                  DropdownMenuItem(
                      value: 'WDV', child: Text('WDV (reducing balance)')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _bookMethod = v);
                },
              ),
              KSpacing.vGapMd,
              if (_bookMethod == 'SLM')
                _field(_usefulLifeCtrl, 'Book useful life (months)',
                    number: true)
              else
                _field(_bookRateCtrl, 'Book rate %', number: true),
              KSpacing.vGapMd,
              _field(_itBlockCtrl, 'IT block (e.g. COMPUTER_40)'),
              KSpacing.vGapMd,
              _field(_itRateCtrl, 'IT rate % (e.g. 40)', number: true),
              KSpacing.vGapLg,
              KButton(
                label: _saving ? 'Saving…' : 'Create asset',
                icon: Icons.save,
                isLoading: _saving,
                onPressed: _save,
              ),
              KSpacing.vGapMd,
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

// ────────────────────── Income-Tax Schedule tab ─────────────────────────────

class _IncomeTaxScheduleTab extends ConsumerStatefulWidget {
  const _IncomeTaxScheduleTab();

  @override
  ConsumerState<_IncomeTaxScheduleTab> createState() =>
      _IncomeTaxScheduleTabState();
}

class _IncomeTaxScheduleTabState
    extends ConsumerState<_IncomeTaxScheduleTab> {
  late int _fy;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fy = now.month >= 4 ? now.year : now.year - 1;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        ApiConfig.fixedAssetIncomeTaxSchedule,
        queryParameters: {'fy': _fy},
      );
      _data = (res.data['data'] as Map?)?.cast<String, dynamic>();
    } catch (e) {
      _error = _dioMessage(e, 'Failed to load income-tax schedule');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final data = _data;
    final blocks = (data?['blocks'] as List?) ?? const [];

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Income-tax depreciation (block of assets)',
                  style: KTypography.h3),
              KSpacing.vGapMd,
              DropdownButtonFormField<int>(
                initialValue: _fy,
                decoration: const InputDecoration(
                  labelText: 'FY starting',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (var y = currentYear; y >= 2024; y--)
                    DropdownMenuItem(
                        value: y, child: Text('$y-${(y + 1) % 100}')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _fy = v);
                  _load();
                },
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (_error != null)
          KErrorView(message: _error!, onRetry: _load)
        else if (data == null || blocks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No block-of-assets data for this FY',
                  style: KTypography.bodyMedium
                      .copyWith(color: KColors.textHint)),
            ),
          )
        else ...[
          KCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FY ${data['fy']}', style: KTypography.labelLarge),
                    Text('Method: ${data['method'] ?? '--'}',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatIndian(
                          _toDouble(data['totalDepreciation'])),
                      style: KTypography.h3.copyWith(color: KColors.primary),
                    ),
                    Text('Total depreciation',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          KSpacing.vGapMd,
          ...blocks.map((raw) {
            final b = Map<String, dynamic>.from(raw as Map);
            return Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.sm),
              child: KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(b['block']?.toString() ?? '--',
                        style: KTypography.labelLarge),
                    KSpacing.vGapSm,
                    _amountRow('Opening WDV', _toDouble(b['openingWdv'])),
                    _amountRow('Additions', _toDouble(b['additions'])),
                    _amountRow('Depreciation', _toDouble(b['depreciation']),
                        color: KColors.primary),
                    _amountRow('Closing WDV', _toDouble(b['closingWdv']),
                        highlight: true),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _amountRow(String label, double value,
      {bool highlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: KTypography.bodyMedium
                  .copyWith(color: KColors.textSecondary)),
          Text(
            CurrencyFormatter.formatIndian(value),
            style: highlight
                ? KTypography.labelLarge.copyWith(color: color ?? KColors.primary)
                : KTypography.bodyMedium.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
