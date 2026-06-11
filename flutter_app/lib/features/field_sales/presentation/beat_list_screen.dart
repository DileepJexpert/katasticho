import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';

class BeatListScreen extends ConsumerStatefulWidget {
  const BeatListScreen({super.key});

  @override
  ConsumerState<BeatListScreen> createState() => _BeatListScreenState();
}

class _BeatListScreenState extends ConsumerState<BeatListScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _beats = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();
  String? _expandedBeatId;

  @override
  void initState() {
    super.initState();
    _loadBeats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBeats() async {
    setState(() => _isLoading = true);
    try {
      final beats = await ref.read(fieldSalesRepositoryProvider).listBeats();
      if (mounted) setState(() => _beats = beats);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load beats: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBeats {
    if (_searchQuery.isEmpty) return _beats;
    final q = _searchQuery.toLowerCase();
    return _beats.where((beat) {
      final haystack = [
        beat['name'],
        beat['code'],
        beat['area'],
        beat['city'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> _showCreateBeatDialog() async {
    final codeCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final areaCtl = TextEditingController();
    final cityCtl = TextEditingController();
    final stateCtl = TextEditingController();
    final descCtl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Beat'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtl,
                decoration: const InputDecoration(
                  labelText: 'Code *',
                  hintText: 'e.g. BEAT-001',
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: nameCtl,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g. MG Road Beat',
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: areaCtl,
                decoration: const InputDecoration(
                  labelText: 'Area',
                  hintText: 'e.g. MG Road',
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: cityCtl,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g. Bengaluru',
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: stateCtl,
                decoration: const InputDecoration(
                  labelText: 'State',
                  hintText: 'e.g. Karnataka',
                ),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: descCtl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (codeCtl.text.trim().isEmpty || nameCtl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Code and Name are required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(fieldSalesRepositoryProvider).createBeat({
        'code': codeCtl.text.trim(),
        'name': nameCtl.text.trim(),
        if (areaCtl.text.trim().isNotEmpty) 'area': areaCtl.text.trim(),
        if (cityCtl.text.trim().isNotEmpty) 'city': cityCtl.text.trim(),
        if (stateCtl.text.trim().isNotEmpty) 'state': stateCtl.text.trim(),
        if (descCtl.text.trim().isNotEmpty)
          'description': descCtl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beat created successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadBeats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create beat: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleExpand(String beatId) async {
    if (_expandedBeatId == beatId) {
      setState(() => _expandedBeatId = null);
      return;
    }
    setState(() => _expandedBeatId = beatId);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBeats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beats'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.md, KSpacing.sm, KSpacing.md, KSpacing.sm),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search beats by name, area...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: KSpacing.borderRadiusMd,
                  borderSide: const BorderSide(color: KColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: KSpacing.borderRadiusMd,
                  borderSide: const BorderSide(color: KColors.divider),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const KLoading()
                : filtered.isEmpty
                    ? KEmptyState(
                        icon: Icons.map_outlined,
                        title: _beats.isEmpty
                            ? 'No beats yet'
                            : 'No matching beats',
                        subtitle: _beats.isEmpty
                            ? 'Create beats to define sales territories for your field team.'
                            : 'Try a different search term.',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBeats,
                        child: ListView.separated(
                          padding: KSpacing.pagePadding,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => KSpacing.vGapSm,
                          itemBuilder: (context, index) {
                            final beat = filtered[index];
                            final beatId = beat['id']?.toString() ?? '';
                            final isExpanded = _expandedBeatId == beatId;
                            return _BeatCard(
                              beat: beat,
                              isExpanded: isExpanded,
                              onTap: () => _toggleExpand(beatId),
                              repo: ref.read(fieldSalesRepositoryProvider),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBeatDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Beat'),
        tooltip: 'New Beat (N)',
      ),
    );
  }
}

class _BeatCard extends StatefulWidget {
  final Map<String, dynamic> beat;
  final bool isExpanded;
  final VoidCallback onTap;
  final FieldSalesRepository repo;

  const _BeatCard({
    required this.beat,
    required this.isExpanded,
    required this.onTap,
    required this.repo,
  });

  @override
  State<_BeatCard> createState() => _BeatCardState();
}

class _BeatCardState extends State<_BeatCard> {
  List<Map<String, dynamic>>? _customers;
  bool _loadingCustomers = false;

  @override
  void didUpdateWidget(covariant _BeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && !oldWidget.isExpanded && _customers == null) {
      _fetchCustomers();
    }
  }

  Future<void> _fetchCustomers() async {
    final beatId = widget.beat['id']?.toString();
    if (beatId == null) return;
    setState(() => _loadingCustomers = true);
    try {
      final customers = await widget.repo.getBeatCustomers(beatId);
      if (mounted) setState(() => _customers = customers);
    } catch (_) {
      // Silently fail - customers section just won't show
    } finally {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.beat['code']?.toString() ?? '--';
    final name = widget.beat['name']?.toString() ?? 'Unnamed Beat';
    final area = widget.beat['area']?.toString();
    final city = widget.beat['city']?.toString();
    final active = widget.beat['active'] != false;
    final location = [area, city].whereType<String>().join(', ');

    return KCard(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.map_outlined,
                    color: KColors.primary, size: 20),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: KTypography.labelLarge,
                              overflow: TextOverflow.ellipsis),
                        ),
                        KSpacing.hGapSm,
                        KStatusChip(
                          status: active ? 'ACTIVE' : 'INACTIVE',
                          label: active ? 'Active' : 'Inactive',
                        ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Row(
                      children: [
                        Text(code,
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary)),
                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.location_on_outlined,
                              size: 12, color: KColors.textSecondary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(location,
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                widget.isExpanded
                    ? Icons.expand_less
                    : Icons.chevron_right,
                color: KColors.textHint,
              ),
            ],
          ),
          if (widget.isExpanded) ...[
            KSpacing.vGapMd,
            const Divider(height: 1),
            KSpacing.vGapSm,
            Text('Customers', style: KTypography.labelMedium),
            KSpacing.vGapXs,
            if (_loadingCustomers)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_customers == null || _customers!.isEmpty)
              Text('No customers assigned to this beat.',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary))
            else
              ...(_customers!.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: KColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c['contactName']?.toString() ??
                                c['name']?.toString() ??
                                'Customer ${c['contactId'] ?? c['id'] ?? ''}',
                            style: KTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ))),
          ],
        ],
      ),
    );
  }
}
