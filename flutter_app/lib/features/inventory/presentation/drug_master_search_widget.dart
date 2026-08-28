import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Searches the platform drug master and calls [onSelected] with the
/// matched drug's data so the item form can auto-fill all pharma fields.
class DrugMasterSearchWidget extends ConsumerStatefulWidget {
  final void Function(Map<String, dynamic> drug) onSelected;

  const DrugMasterSearchWidget({super.key, required this.onSelected});

  @override
  ConsumerState<DrugMasterSearchWidget> createState() =>
      _DrugMasterSearchWidgetState();
}

class _DrugMasterSearchWidgetState
    extends ConsumerState<DrugMasterSearchWidget> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;
  bool _showDropdown = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() {
        _results = [];
        _showDropdown = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        ApiConfig.drugMasterSearch,
        queryParameters: {'q': q, 'limit': 15},
      );
      final raw = res.data;
      List list = [];
      if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else if (raw is List) {
        list = raw;
      }
      if (mounted) {
        setState(() {
          _results = list.cast<Map<String, dynamic>>();
          _showDropdown = _results.isNotEmpty;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(Map<String, dynamic> drug) {
    _controller.clear();
    setState(() {
      _results = [];
      _showDropdown = false;
    });
    _focusNode.unfocus();
    widget.onSelected(drug);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: KColors.primary.withValues(alpha: 0.06),
            borderRadius: KSpacing.borderRadiusMd,
            border: Border.all(color: KColors.primary.withValues(alpha: 0.25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.local_pharmacy_outlined,
                  size: 18, color: KColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search drug database (name, salt, generic)…',
                    hintStyle:
                        KTypography.bodySmall.copyWith(color: KColors.textHint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  style: KTypography.bodyMedium,
                  onChanged: _onChanged,
                ),
              ),
            ],
          ),
        ),
        if (_showDropdown && _results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: KSpacing.borderRadiusMd,
              border: Border.all(color: cs.outlineVariant),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.outlineVariant),
              itemBuilder: (ctx, i) {
                final d = _results[i];
                final schedule = d['drugSchedule'] as String? ?? '';
                final rx = d['prescriptionRequired'] as bool? ?? false;
                final mrp = (d['mrp'] as num?)?.toDouble();
                return InkWell(
                  onTap: () => _select(d),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      d['brandName'] ?? '',
                                      style: KTypography.labelMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (rx) ...[
                                    const SizedBox(width: 6),
                                    _tag('Rx', KColors.error),
                                  ],
                                  if (schedule.isNotEmpty &&
                                      schedule != 'GENERAL') ...[
                                    const SizedBox(width: 4),
                                    _tag('Sch $schedule',
                                        const Color(0xFF6A1B9A)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                d['saltComposition'] ?? d['genericName'] ?? '',
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((d['manufacturer'] as String?)?.isNotEmpty ==
                                  true)
                                Text(
                                  '${d['manufacturer']} • ${d['dosageForm'] ?? ''} • ${d['packSize'] ?? ''}',
                                  style: KTypography.labelSmall.copyWith(
                                      color: KColors.textHint, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        if (mrp != null) ...[
                          const SizedBox(width: 8),
                          KMoney(
                            mrp,
                            size: KMoneySize.small,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: KTypography.labelSmall
              .copyWith(color: color, fontSize: 9, fontWeight: FontWeight.w700),
        ),
      );
}
