import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// HSN → GST rate master. The table is shared across all orgs (rates are
/// statutory facts): admins can ADD missing codes; editing an existing code
/// needs a platform admin, so the backend rejects those with a clear error.
class HsnMasterScreen extends ConsumerStatefulWidget {
  const HsnMasterScreen({super.key});

  @override
  ConsumerState<HsnMasterScreen> createState() => _HsnMasterScreenState();
}

class _HsnMasterScreenState extends ConsumerState<HsnMasterScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final response = await ref.read(apiClientProvider).get(
        ApiConfig.hsnGstMasterSearch,
        queryParameters: {'q': q, 'limit': 50},
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() => _results =
            (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? []);
      }
    } catch (e) {
      _toast('Search failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addHsn() async {
    final codeCtl = TextEditingController();
    final descCtl = TextEditingController();
    final rateCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add HSN / SAC Master Code', style: KTypography.titleLarge),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KTextField(
                controller: codeCtl,
                autofocus: true,
                label: 'HSN / SAC Code',
                hint: 'e.g. 3004 or 1905',
              ),
              KSpacing.vGapSm,
              KTextField(
                controller: descCtl,
                label: 'Statutory Goods Description',
                hint: 'e.g. Medicaments consisting of mixed or unmixed products',
                maxLines: 2,
              ),
              KSpacing.vGapSm,
              KTextField(
                controller: rateCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                label: 'Applicable GST Rate (%)',
                hint: 'e.g. 5, 12, or 18',
              ),
            ],
          ),
        ),
        actions: [
          KButton.outlined(
            label: 'Cancel',
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            label: 'Save HSN Code',
            icon: Icons.check,
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(apiClientProvider).post(
        ApiConfig.pharmacyHsnUpsert,
        data: {
          'hsnCode': codeCtl.text.trim(),
          'description': descCtl.text.trim(),
          'gstRate': double.tryParse(rateCtl.text) ?? 0,
        },
      );
      _toast('HSN code saved successfully');
      _search(_searchCtrl.text);
    } catch (e) {
      _toast('Save failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HSN / SAC GST Rate Directory')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: _addHsn,
        icon: const Icon(Icons.add),
        label: const Text('Add HSN Code'),
      ),
      body: Column(
        children: [
          Padding(
            padding: KSpacing.pagePadding,
            child: KTextField(
              controller: _searchCtrl,
              label: 'Search HSN Directory',
              hint: 'Search by 2/4/6/8-digit HSN code or statutory product description',
              prefixIcon: Icons.search,
              onChanged: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? const KEmptyState(
                    icon: Icons.find_in_page_outlined,
                    title: 'No HSN Codes Found',
                    subtitle: 'Search by HSN code or keyword, or tap "Add HSN Code" to register a new statutory classification.',
                  )
                : ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, i) {
                      final h = _results[i];
                      final gstRate = (h['gstRate'] as num?)?.toDouble() ?? 0;
                      return KCard(
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: KColors.primary.withValues(alpha: 0.12),
                                borderRadius: KSpacing.borderRadiusSm,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${gstRate.toStringAsFixed(gstRate.truncateToDouble() == gstRate ? 0 : 1)}%',
                                style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700, color: KColors.primary),
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
                                        h['hsnCode']?.toString() ?? '',
                                        style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
                                      ),
                                      KSpacing.hGapSm,
                                      KStatusChip(status: '${gstRate.toInt()}% GST'),
                                    ],
                                  ),
                                  KSpacing.vGapXs,
                                  Text(
                                    h['description']?.toString() ?? '—',
                                    style: KTypography.bodySmall,
                                  ),
                                  if (h['category'] != null) ...[
                                    KSpacing.vGapXs,
                                    Text(
                                      h['category'].toString(),
                                      style: KTypography.caption.copyWith(color: KColors.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
