import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';

/// Autocomplete search widget for manufacturers from the pharmacy master.
///
/// Calls `GET /api/v1/pharmacy-masters/manufacturers/search?q=<query>&limit=10`
/// and presents matching manufacturer names and countries. When the user taps
/// a result the [onSelected] callback fires with the manufacturer's name and
/// the text field is filled accordingly.
class ManufacturerSearchWidget extends ConsumerStatefulWidget {
  const ManufacturerSearchWidget({
    super.key,
    required this.onSelected,
    this.controller,
    this.initialValue,
  });

  /// Called when the user picks a manufacturer from the dropdown.
  final void Function(String name) onSelected;

  /// Optional external controller so the parent can read/reset the value.
  final TextEditingController? controller;

  /// Pre-fill the text field in edit mode (e.g. when editing an existing item).
  final String? initialValue;

  @override
  ConsumerState<ManufacturerSearchWidget> createState() =>
      _ManufacturerSearchWidgetState();
}

class _ManufacturerSearchWidgetState
    extends ConsumerState<ManufacturerSearchWidget> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();

    if (widget.initialValue != null &&
        widget.initialValue!.isNotEmpty &&
        _controller.text.isEmpty) {
      _controller.text = widget.initialValue!;
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

  // ── API call ──

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
        ApiConfig.manufacturerMasterSearch,
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
    final name = entry['name']?.toString() ?? '';
    _controller.text = name;
    setState(() {
      _results = [];
      _showDropdown = false;
    });
    _focusNode.unfocus();
    widget.onSelected(name);
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
              Icon(Icons.factory_outlined,
                  size: 18, color: KColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search manufacturer…',
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
                final name = d['name']?.toString() ?? '';
                final country = d['country']?.toString() ?? '';
                final website = d['website']?.toString() ?? '';

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
                              Text(
                                name,
                                style: KTypography.labelMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (country.isNotEmpty ||
                                  website.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  [
                                    if (country.isNotEmpty) country,
                                    if (website.isNotEmpty) website,
                                  ].join(' • '),
                                  style: KTypography.bodySmall
                                      .copyWith(color: KColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (country.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _countryTag(country),
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

  // ── Helper widgets ──

  Widget _countryTag(String country) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: KColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          country,
          style: KTypography.labelSmall.copyWith(
              color: KColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w600),
        ),
      );
}
