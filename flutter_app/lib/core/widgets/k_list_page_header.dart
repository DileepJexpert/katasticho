import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// A tab/chip definition for [KListPageHeader].
class KListTab {
  final String? value; // null = "All"
  final String label;

  const KListTab({required this.label, this.value});
}

/// Standardized list-screen page header — **Katasticho 2026 / Phase 5**.
///
/// Replaces the individual Scaffold AppBar + filter chip row pattern on
/// every list screen. Provides:
///   • Title row with inline expandable search + optional trailing actions
///   • Horizontally-scrollable tab chips for status/type filtering
///   • 1px bottom border (no elevation)
///
/// Usage:
/// ```dart
/// Scaffold(
///   body: Column(children: [
///     KListPageHeader(
///       title: 'Invoices',
///       tabs: _statusFilters,
///       selectedTab: filter.status,
///       onTabChanged: (v) => ref.read(filterProvider.notifier).state = ...,
///       onSearchChanged: (q) => ...,
///     ),
///     Expanded(child: listContent),
///   ]),
///   floatingActionButton: ...,
/// )
/// ```
class KListPageHeader extends StatefulWidget {
  final String title;
  final List<KListTab>? tabs;
  final String? selectedTab;
  final ValueChanged<String?>? onTabChanged;
  final String searchHint;
  final ValueChanged<String>? onSearchChanged;
  final TextEditingController? searchController;
  final List<Widget>? actions;

  const KListPageHeader({
    super.key,
    required this.title,
    this.tabs,
    this.selectedTab,
    this.onTabChanged,
    this.searchHint = 'Search…',
    this.onSearchChanged,
    this.searchController,
    this.actions,
  });

  @override
  State<KListPageHeader> createState() => _KListPageHeaderState();
}

class _KListPageHeaderState extends State<KListPageHeader> {
  bool _searchExpanded = false;
  late TextEditingController _internalController;
  final _focusNode = FocusNode();

  TextEditingController get _controller =>
      widget.searchController ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
  }

  @override
  void dispose() {
    _internalController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _controller.clear();
    widget.onSearchChanged?.call('');
    setState(() => _searchExpanded = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTabs = widget.tabs != null && widget.tabs!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.7),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title row ────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _searchExpanded
                    ? _SearchRow(
                        key: const ValueKey('search'),
                        controller: _controller,
                        focusNode: _focusNode,
                        hint: widget.searchHint,
                        onChanged: widget.onSearchChanged,
                        onClose: _closeSearch,
                      )
                    : _TitleRow(
                        key: const ValueKey('title'),
                        title: widget.title,
                        actions: widget.actions,
                        onSearchTap: widget.onSearchChanged != null
                            ? _openSearch
                            : null,
                      ),
              ),
            ),
          ),

          // ── Tab chips ────────────────────────────────────────────
          if (hasTabs)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: widget.tabs!.map((tab) {
                  final isActive = widget.selectedTab == tab.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _TabChip(
                      label: tab.label,
                      active: isActive,
                      onTap: () => widget.onTabChanged?.call(tab.value),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onSearchTap;

  const _TitleRow({
    super.key,
    required this.title,
    this.actions,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: KTypography.h2.copyWith(color: cs.onSurface),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onSearchTap != null)
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 20),
            tooltip: 'Search',
            color: cs.onSurfaceVariant,
            visualDensity: VisualDensity.compact,
            onPressed: onSearchTap,
          ),
        if (actions != null)
          ...actions!.map((a) => a),
      ],
    );
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback onClose;

  const _SearchRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          color: cs.onSurfaceVariant,
          visualDensity: VisualDensity.compact,
          onPressed: onClose,
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: KTypography.bodyMedium.copyWith(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: KTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, value, __) => value.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(KSpacing.radiusRound),
          border: Border.all(
            color: active ? cs.primary.withValues(alpha: 0.4) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: KTypography.labelSmall.copyWith(
            color: active ? cs.primary : cs.onSurfaceVariant,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
