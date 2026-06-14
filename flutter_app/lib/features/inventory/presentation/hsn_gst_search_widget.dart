import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';

/// Autocomplete search widget for HSN codes from the pharmacy master.
///
/// Calls `GET /api/v1/pharmacy-masters/hsn/search?q=<query>&limit=10` and
/// displays matching HSN codes with their GST rate. When the user taps a
/// result the [onSelected] callback fires with `hsnCode`, `gstRate`, and
/// `description`, and a "GST: X%" chip is rendered next to the text field.
class HsnGstSearchWidget extends ConsumerStatefulWidget {
  const HsnGstSearchWidget({
    super.key,
    required this.onSelected,
    this.initialHsnCode,
    this.controller,
  });

  /// Called when the user picks an HSN entry from the dropdown.
  final void Function(String hsnCode, double gstRate, String description)
      onSelected;

  /// Pre-fill the text field in edit mode (e.g. when editing an existing item).
  final String? initialHsnCode;

  /// Optional external controller so the parent can read/reset the value.
  final TextEditingController? controller;

  @override
  ConsumerState<HsnGstSearchWidget> createState() =>
      _HsnGstSearchWidgetState();
}

class _HsnGstSearchWidgetState extends ConsumerState<HsnGstSearchWidget> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;
  bool _showDropdown = false;

  /// Tracks the currently selected GST rate so we can render the chip.
  double? _selectedGstRate;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();

    if (widget.initialHsnCode != null &&
        widget.initialHsnCode!.isNotEmpty &&
        _controller.text.isEmpty) {
      _controller.text = widget.initialHsnCode!;
      // Fetch the initial HSN entry to populate the GST chip.
      _fetchInitialHsn(widget.initialHsnCode!);
    }

    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    // Hide dropdown when focus is lost.
    if (!_focusNode.hasFocus && _showDropdown) {
      // Small delay so the tap on a dropdown item can fire first.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          setState(() => _showDropdown = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    // Only dispose the controller if we created it.
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  // ── API calls ──

  Future<void> _fetchInitialHsn(String code) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        ApiConfig.hsnGstByCode(code),
      );
      final raw = res.data;
      Map<String, dynamic>? entry;
      if (raw is Map && raw['data'] is Map) {
        entry = (raw['data'] as Map).cast<String, dynamic>();
      } else if (raw is Map) {
        entry = raw.cast<String, dynamic>();
      }
      if (entry != null && mounted) {
        setState(() {
          _selectedGstRate = (entry!['gstRate'] as num?)?.toDouble();
        });
      }
    } catch (_) {
      // Silently ignore — user can still search.
    }
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
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(
        ApiConfig.hsnGstMasterSearch,
        queryParameters: {'q': q, 'limit': 10},
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

  void _select(Map<String, dynamic> entry) {
    final hsnCode = entry['hsnCode']?.toString() ?? '';
    final gstRate = (entry['gstRate'] as num?)?.toDouble() ?? 0.0;
    final description = entry['description']?.toString() ?? '';

    _controller.text = hsnCode;
    setState(() {
      _results = [];
      _showDropdown = false;
      _selectedGstRate = gstRate;
    });
    _focusNode.unfocus();
    widget.onSelected(hsnCode, gstRate, description);
  }

  // ── Build ──

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
              Icon(Icons.qr_code_2_outlined,
                  size: 18, color: KColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search HSN code or description…',
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
              if (_selectedGstRate != null) ...[
                const SizedBox(width: 8),
                _gstChip(_selectedGstRate!),
              ],
            ],
          ),
        ),

        // ── Dropdown results ──
        if (_showDropdown && _results.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: KSpacing.borderRadiusMd,
              border: Border.all(color: cs.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.outlineVariant),
              itemBuilder: (ctx, i) {
                final d = _results[i];
                final hsnCode = d['hsnCode']?.toString() ?? '';
                final description = d['description']?.toString() ?? '';
                final category = d['category']?.toString() ?? '';
                final gstRate = (d['gstRate'] as num?)?.toDouble() ?? 0.0;

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
                                  Text(
                                    hsnCode,
                                    style: KTypography.labelMedium.copyWith(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  if (category.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    _tag(category, KColors.primary),
                                  ],
                                ],
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  style: KTypography.bodySmall
                                      .copyWith(color: KColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _gstBadge(gstRate),
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

  // ── Helper widgets ──

  /// Small coloured tag (category label in the dropdown row).
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

  /// GST rate badge shown to the right of each dropdown row.
  Widget _gstBadge(double rate) {
    final color = _gstColor(rate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}%',
        style: KTypography.labelSmall
            .copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// GST chip displayed inline next to the text field after selection.
  Widget _gstChip(double rate) {
    final color = _gstColor(rate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'GST: ${rate.toStringAsFixed(rate.truncateToDouble() == rate ? 0 : 2)}%',
        style: KTypography.labelSmall
            .copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  /// Return a colour that varies by GST slab for quick visual scanning.
  Color _gstColor(double rate) {
    if (rate <= 5) return const Color(0xFF2E7D32); // green — low
    if (rate <= 12) return const Color(0xFFEF6C00); // orange — mid
    return const Color(0xFFC62828); // red — high (18%+)
  }
}
