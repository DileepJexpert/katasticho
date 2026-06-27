import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/intl/country_currency.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Gulf VAT return — UAE VAT201 (`/api/v1/vat/uae`) and Oman VAT
/// (`/api/v1/vat/oman`). Both backends are country-gated (`@RequiresCountry`),
/// so the wrong region returns a friendly "not registered" message. Renders
/// the box rollups (1a/1b standard supplies + output VAT, 9/10 expenses +
/// recoverable input VAT, 14 net VAT due) and exports the filing JSON.
class VatReturnScreen extends ConsumerStatefulWidget {
  const VatReturnScreen({super.key});

  @override
  ConsumerState<VatReturnScreen> createState() => _VatReturnScreenState();
}

class _VatReturnScreenState extends ConsumerState<VatReturnScreen> {
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  String _region = 'uae'; // 'uae' | 'oman'
  late DateTime _from;
  late DateTime _to;
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final qStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    _from = DateTime(now.year, qStartMonth, 1);
    _to = now;
    // Default the region from the org's country when it's already cached.
    final cc = ref.read(countryProfileProvider).valueOrNull?.countryCode;
    if (cc == 'OM') _region = 'oman';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.vatReturn(
                _region, _dateFmt.format(_from), _dateFmt.format(_to)),
          );
      _data = (res.data['data'] as Map?)?.cast<String, dynamic>();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      _error = code == 403
          ? 'This organisation is not registered for ${_region == 'uae' ? 'UAE' : 'Oman'} VAT.'
          : _msg(e) ?? 'Failed to load VAT return';
      _data = null;
    } catch (_) {
      _error = 'Failed to load VAT return';
      _data = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Generating filing JSON…')));
    try {
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.vatReturnExport(
                _region, _dateFmt.format(_from), _dateFmt.format(_to)),
            options: Options(responseType: ResponseType.bytes),
          );
      final bytes = res.data as List<int>;
      await Share.share(
        String.fromCharCodes(bytes),
        subject:
            'VAT201_${_region.toUpperCase()}_${_dateFmt.format(_from)}_${_dateFmt.format(_to)}.json',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2018),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VAT Return'),
        actions: [
          IconButton(
            tooltip: 'Export filing JSON',
            icon: const Icon(Icons.download_outlined),
            onPressed: _data == null ? null : _export,
          ),
        ],
      ),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'uae', label: Text('UAE VAT201')),
                      ButtonSegment(value: 'oman', label: Text('Oman VAT')),
                    ],
                    selected: {_region},
                    onSelectionChanged: (s) {
                      setState(() => _region = s.first);
                      _load();
                    },
                  ),
                  KSpacing.vGapMd,
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    label: Text(
                        '${_dateFmt.format(_from)}  →  ${_dateFmt.format(_to)}'),
                  ),
                ],
              ),
            ),
          ),
          KSpacing.vGapMd,
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: KColors.warning),
                    KSpacing.hGapSm,
                    Expanded(
                        child: Text(_error!, style: KTypography.bodyMedium)),
                  ],
                ),
              ),
            )
          else if (_data != null)
            ..._returnCards(_data!),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  List<Widget> _returnCards(Map<String, dynamic> d) {
    final meta = (d['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final currency = meta['currency']?.toString() ?? '';
    String fmt(dynamic v) {
      final n = v is num ? v : num.tryParse('${v ?? 0}') ?? 0;
      final s = NumberFormat('#,##0.00').format(n);
      return currency.isEmpty ? s : '$currency $s';
    }

    return [
      _boxCard('Box 1a — Standard-rated supplies',
          fmt(d['box1aStandardRatedSupplies'])),
      _boxCard('Box 1b — Output VAT', fmt(d['box1bOutputVat'])),
      _boxCard('Box 9 — Standard-rated expenses',
          fmt(d['box9StandardRatedExpenses'])),
      _boxCard('Box 10 — Recoverable input VAT',
          fmt(d['box10RecoverableInputVat'])),
      _boxCard('Box 14 — Net VAT due', fmt(d['box14NetVatDue']),
          highlight: true),
      if (meta.isNotEmpty) ...[
        KSpacing.vGapMd,
        KCard(
          title: 'Details',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
            child: Column(
              children: [
                for (final e in meta.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_prettyKey(e.key),
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                        Flexible(
                          child: Text('${e.value}',
                              textAlign: TextAlign.right,
                              style: KTypography.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _boxCard(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: highlight
                        ? KTypography.labelLarge
                        : KTypography.bodyMedium),
              ),
              Text(value,
                  style: (highlight ? KTypography.h3 : KTypography.labelLarge)
                      .copyWith(
                          color: highlight ? KColors.primary : null)),
            ],
          ),
        ),
      ),
    );
  }

  static String _prettyKey(String k) {
    final spaced = k.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return spaced.isEmpty
        ? k
        : spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String? _msg(DioException e) {
    final body = e.response?.data;
    return body is Map ? body['message'] as String? : null;
  }
}
