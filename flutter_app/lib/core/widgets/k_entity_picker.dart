import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import 'k_text_field.dart';

/// A selectable row in [showEntityPicker] / [KEntityPickerField].
class EntityOption {
  final String id;
  final String label;
  final String? subtitle;

  /// The full backing map, when the caller needs more than id/label.
  final Map<String, dynamic>? raw;

  const EntityOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.raw,
  });
}

/// Caller-supplied search. Receives the (trimmed) query — empty string for the
/// initial/unfiltered load — and returns the matching options.
typedef EntitySearchFn = Future<List<EntityOption>> Function(String query);

/// Generic searchable entity picker. Replaces "paste-a-UUID" text fields across
/// the app: the caller supplies any [search] data source and gets back the
/// chosen [EntityOption] (or null if cancelled). Deliberately free of Riverpod
/// so it can be dropped into any screen regardless of its data layer.
Future<EntityOption?> showEntityPicker(
  BuildContext context, {
  required String title,
  required EntitySearchFn search,
  String hint = 'Search…',
}) {
  return showModalBottomSheet<EntityOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => _EntityPickerSheet(
        title: title,
        hint: hint,
        search: search,
        scrollController: scrollController,
      ),
    ),
  );
}

class _EntityPickerSheet extends StatefulWidget {
  final String title;
  final String hint;
  final EntitySearchFn search;
  final ScrollController scrollController;

  const _EntityPickerSheet({
    required this.title,
    required this.hint,
    required this.search,
    required this.scrollController,
  });

  @override
  State<_EntityPickerSheet> createState() => _EntityPickerSheetState();
}

class _EntityPickerSheetState extends State<_EntityPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  Object? _error;
  List<EntityOption> _results = const [];
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
        const Duration(milliseconds: 300), () => _runSearch(v.trim()));
  }

  Future<void> _runSearch(String q) async {
    final req = ++_reqId; // ignore stale responses
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.search(q);
      if (!mounted || req != _reqId) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || req != _reqId) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.sm, KSpacing.md, KSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: KTypography.h4),
                KSpacing.vGapSm,
                KTextField.search(
                  controller: _searchController,
                  hint: widget.hint,
                  onChanged: _onChanged,
                  onClear: () {
                    _searchController.clear();
                    _runSearch('');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load', style: KTypography.bodyMedium),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No matches', style: KTypography.bodyMedium),
        ),
      );
    }
    return ListView.separated(
      controller: widget.scrollController,
      padding: KSpacing.pagePadding,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final o = _results[index];
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(o.label,
              style: KTypography.labelMedium, overflow: TextOverflow.ellipsis),
          subtitle: o.subtitle != null
              ? Text(o.subtitle!,
                  style: KTypography.bodySmall, overflow: TextOverflow.ellipsis)
              : null,
          onTap: () => Navigator.pop(context, o),
        );
      },
    );
  }
}

/// A tappable form field that shows the currently-selected entity and opens
/// [showEntityPicker] on tap — the drop-in replacement for a raw "paste a UUID"
/// `TextField`.
class KEntityPickerField extends StatelessWidget {
  final String label;
  final String? pickerTitle;
  final String hint;
  final EntityOption? value;
  final EntitySearchFn search;
  final ValueChanged<EntityOption?> onChanged;
  final IconData icon;
  final bool allowClear;

  const KEntityPickerField({
    super.key,
    required this.label,
    required this.search,
    required this.onChanged,
    this.value,
    this.pickerTitle,
    this.hint = 'Search…',
    this.icon = Icons.search,
    this.allowClear = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final picked = await showEntityPicker(
          context,
          title: pickerTitle ?? label,
          search: search,
          hint: hint,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          suffixIcon: (allowClear && hasValue)
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          hasValue ? value!.label : 'Tap to select',
          style: hasValue
              ? KTypography.bodyMedium
              : KTypography.bodyMedium.copyWith(color: KColors.textHint),
        ),
      ),
    );
  }
}
