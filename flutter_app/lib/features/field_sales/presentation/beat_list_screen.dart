import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';
import 'beat_customer_picker_sheet.dart';

class BeatListScreen extends ConsumerStatefulWidget {
  const BeatListScreen({super.key});

  @override
  ConsumerState<BeatListScreen> createState() => _BeatListScreenState();
}

class _BeatListScreenState extends ConsumerState<BeatListScreen> {
  final _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _beats = [];
  String _searchQuery = '';
  String? _expandedBeatId;
  int _customerAssignmentsRevision = 0;

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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load beats: ${ApiErrorParser.message(error)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBeats {
    if (_searchQuery.isEmpty) return _beats;
    final query = _searchQuery.toLowerCase();
    return _beats.where((beat) {
      final haystack = [
        beat['name'],
        beat['code'],
        beat['area'],
        beat['city'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  bool get _canManageBeats {
    final role = ref.read(authProvider).role?.toUpperCase();
    return role == 'OWNER' || role == 'ADMIN';
  }

  Future<void> _openBeatEditor([Map<String, dynamic>? beat]) async {
    if (!_canManageBeats) return;

    List<Map<String, dynamic>> selectedCustomers = [];
    final beatId = beat?['id']?.toString();
    if (beatId != null && beatId.isNotEmpty) {
      try {
        selectedCustomers = await ref
            .read(fieldSalesRepositoryProvider)
            .getBeatCustomers(beatId);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load assigned customers: ${ApiErrorParser.message(error)}'),
              backgroundColor: KColors.error,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _BeatEditorDialog(
        beat: beat,
        selectedCustomers: selectedCustomers,
      ),
    );
    if (payload == null || !mounted) return;

    try {
      if (beatId == null || beatId.isEmpty) {
        await ref.read(fieldSalesRepositoryProvider).createBeat(payload);
      } else {
        await ref.read(fieldSalesRepositoryProvider).updateBeat(beatId, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(beatId == null ? 'Beat created' : 'Beat updated'),
          backgroundColor: KColors.success,
        ),
      );
      await _loadBeats();
      if (mounted) {
        // Expanded cards cache their stop list; force it to reload after the
        // assignment plan has been replaced by this save.
        setState(() => _customerAssignmentsRevision++);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save beat: ${ApiErrorParser.message(error)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  void _toggleExpand(String beatId) {
    setState(() => _expandedBeatId = _expandedBeatId == beatId ? null : beatId);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBeats;
    final canManage = ref.watch(authProvider.select((state) {
      final role = state.role?.toUpperCase();
      return role == 'OWNER' || role == 'ADMIN';
    }));

    return KKeyboardListWrapper(
      itemCount: () => filtered.length,
      onNew: canManage ? () => _openBeatEditor() : null,
      onRefresh: _loadBeats,
      child: Scaffold(
        appBar: AppBar(title: const Text('Beats')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.md,
                KSpacing.sm,
                KSpacing.md,
                KSpacing.sm,
              ),
              child: KTextField.search(
                controller: _searchController,
                hint: 'Search beats by name, area or city',
                onChanged: (value) => setState(() => _searchQuery = value),
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
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
                              ? 'Create a beat, then assign the customer stops for the field team.'
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
                              return _BeatCard(
                                beat: beat,
                                isExpanded: _expandedBeatId == beatId,
                                canManage: canManage,
                                customerAssignmentsRevision:
                                    _customerAssignmentsRevision,
                                onTap: () => _toggleExpand(beatId),
                                onEdit: () => _openBeatEditor(beat),
                                repo: ref.read(fieldSalesRepositoryProvider),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
        floatingActionButton: canManage
            ? FloatingActionButton.extended(
                backgroundColor: KColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _openBeatEditor(),
                icon: const Icon(Icons.add),
                label: const Text('New Beat'),
                tooltip: 'New Beat (N)',
              )
            : null,
      ),
    );
  }
}

class _BeatCard extends StatefulWidget {
  const _BeatCard({
    required this.beat,
    required this.isExpanded,
    required this.canManage,
    required this.customerAssignmentsRevision,
    required this.onTap,
    required this.onEdit,
    required this.repo,
  });

  final Map<String, dynamic> beat;
  final bool isExpanded;
  final bool canManage;
  final int customerAssignmentsRevision;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final FieldSalesRepository repo;

  @override
  State<_BeatCard> createState() => _BeatCardState();
}

class _BeatCardState extends State<_BeatCard> {
  List<Map<String, dynamic>>? _customers;
  bool _isLoadingCustomers = false;

  @override
  void didUpdateWidget(covariant _BeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerAssignmentsRevision !=
        widget.customerAssignmentsRevision) {
      _customers = null;
      if (widget.isExpanded) {
        _fetchCustomers();
      }
      return;
    }
    if (widget.isExpanded && !oldWidget.isExpanded && _customers == null) {
      _fetchCustomers();
    }
  }

  Future<void> _fetchCustomers() async {
    final beatId = widget.beat['id']?.toString();
    if (beatId == null || beatId.isEmpty) return;
    setState(() => _isLoadingCustomers = true);
    try {
      final customers = await widget.repo.getBeatCustomers(beatId);
      if (mounted) setState(() => _customers = customers);
    } finally {
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  String _customerName(Map<String, dynamic> customer) {
    return customer['contactName']?.toString() ??
        customer['displayName']?.toString() ??
        customer['companyName']?.toString() ??
        'Unnamed customer';
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.beat['code']?.toString() ?? '--';
    final name = widget.beat['name']?.toString() ?? 'Unnamed Beat';
    final area = widget.beat['area']?.toString();
    final city = widget.beat['city']?.toString();
    final active = widget.beat['active'] != false;
    final location = [area, city]
        .where((part) => part != null && part.isNotEmpty)
        .join(', ');

    return KCard(
      statusAccent: active ? KColors.primary : null,
      onTap: widget.onTap,
      leading: const Icon(Icons.map_outlined, color: KColors.primary),
      title: name,
      subtitleWidget: Row(
        children: [
          Text(
            code,
            style: KTypography.mono(
              fontSize: 12,
              color: KColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (location.isNotEmpty)
            Expanded(
              child: Text(
                ' • $location',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KStatusChip(
            status: active ? 'ACTIVE' : 'INACTIVE',
            label: active ? 'Active' : 'Inactive',
          ),
          if (widget.canManage) ...[
            KSpacing.hGapSm,
            KButton.outlined(
              label: 'Edit',
              size: KButtonSize.small,
              icon: Icons.edit_outlined,
              onPressed: widget.onEdit,
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isExpanded)
            Text('Tap to view assigned customer stops',
                style: KTypography.bodySmall.copyWith(
                  color: KColors.textSecondary,
                ))
          else ...[
            const Divider(height: 1),
            KSpacing.vGapSm,
            Text('Customer stops', style: KTypography.labelMedium),
            KSpacing.vGapXs,
            if (_isLoadingCustomers)
              const Padding(
                padding: EdgeInsets.all(KSpacing.sm),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_customers == null || _customers!.isEmpty)
              Text('No customers assigned to this beat.',
                  style: KTypography.bodySmall.copyWith(
                    color: KColors.textSecondary,
                  ))
            else ...[
              for (final customer in _customers!.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.xs),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: KColors.textSecondary),
                      KSpacing.hGapXs,
                      Expanded(
                        child: Text(_customerName(customer),
                            style: KTypography.bodySmall),
                      ),
                    ],
                  ),
                ),
              if (_customers!.length > 5)
                Text('+ ${_customers!.length - 5} more customers',
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    )),
            ],
          ],
        ],
      ),
    );
  }
}

class _BeatEditorDialog extends StatefulWidget {
  const _BeatEditorDialog({
    this.beat,
    required this.selectedCustomers,
  });

  final Map<String, dynamic>? beat;
  final List<Map<String, dynamic>> selectedCustomers;

  @override
  State<_BeatEditorDialog> createState() => _BeatEditorDialogState();
}

class _BeatEditorDialogState extends State<_BeatEditorDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _areaController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _descriptionController;
  late List<Map<String, dynamic>> _selectedCustomers;

  @override
  void initState() {
    super.initState();
    final beat = widget.beat;
    _codeController = TextEditingController(text: beat?['code']?.toString());
    _nameController = TextEditingController(text: beat?['name']?.toString());
    _areaController = TextEditingController(text: beat?['area']?.toString());
    _cityController = TextEditingController(text: beat?['city']?.toString());
    _stateController = TextEditingController(text: beat?['state']?.toString());
    _descriptionController =
        TextEditingController(text: beat?['description']?.toString());
    _selectedCustomers = List.of(widget.selectedCustomers);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectCustomers() async {
    final customers = await showBeatCustomerPickerSheet(
      context,
      selectedCustomers: _selectedCustomers,
    );
    if (customers != null && mounted) {
      setState(() => _selectedCustomers = customers);
    }
  }

  String _customerName(Map<String, dynamic> customer) {
    return customer['displayName']?.toString() ??
        customer['contactName']?.toString() ??
        customer['companyName']?.toString() ??
        'Unnamed customer';
  }

  void _save() {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code and name are required.')),
      );
      return;
    }

    Navigator.pop(context, {
      'code': code,
      'name': name,
      if (_areaController.text.trim().isNotEmpty)
        'area': _areaController.text.trim(),
      if (_cityController.text.trim().isNotEmpty)
        'city': _cityController.text.trim(),
      if (_stateController.text.trim().isNotEmpty)
        'state': _stateController.text.trim(),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
      'customers': [
        for (var index = 0; index < _selectedCustomers.length; index++)
          {
            'contactId': _selectedCustomers[index]['contactId']?.toString() ??
                _selectedCustomers[index]['id']?.toString(),
            'visitSequence': index + 1,
            'visitFrequency': 'WEEKLY',
          },
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.beat != null;
    final selectedNames = _selectedCustomers
        .take(3)
        .map(_customerName)
        .join(', ');

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Padding(
          padding: KSpacing.pagePaddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(editing ? 'Edit Beat' : 'New Beat',
                  style: KTypography.titleLarge),
              KSpacing.vGapMd,
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      KTextField(
                        label: 'Beat code',
                        hint: 'e.g. GONDA-MAIN-01',
                        controller: _codeController,
                        isRequired: true,
                        readOnly: editing,
                      ),
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'Beat name',
                        hint: 'e.g. Gonda Main Market',
                        controller: _nameController,
                        isRequired: true,
                      ),
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'Area',
                        hint: 'e.g. Main Market',
                        controller: _areaController,
                      ),
                      KSpacing.vGapSm,
                      Row(
                        children: [
                          Expanded(
                            child: KTextField(
                              label: 'City',
                              hint: 'e.g. Gonda',
                              controller: _cityController,
                            ),
                          ),
                          KSpacing.hGapSm,
                          Expanded(
                            child: KTextField(
                              label: 'State',
                              hint: 'e.g. Uttar Pradesh',
                              controller: _stateController,
                            ),
                          ),
                        ],
                      ),
                      KSpacing.vGapSm,
                      KTextField(
                        label: 'Description',
                        hint: 'Optional operational notes',
                        controller: _descriptionController,
                        maxLines: 2,
                      ),
                      KSpacing.vGapMd,
                      KCard(
                        title: 'Customer stops',
                        subtitle: _selectedCustomers.isEmpty
                            ? 'No customers selected yet'
                            : '${_selectedCustomers.length} customer${_selectedCustomers.length == 1 ? '' : 's'} assigned',
                        action: KButton.outlined(
                          label: 'Manage',
                          icon: Icons.people_outline,
                          size: KButtonSize.small,
                          onPressed: _selectCustomers,
                        ),
                        child: _selectedCustomers.isEmpty
                            ? Text(
                                'Select the retailers or customers this field route should visit.',
                                style: KTypography.bodySmall.copyWith(
                                  color: KColors.textSecondary,
                                ),
                              )
                            : Text(
                                selectedNames +
                                    (_selectedCustomers.length > 3
                                        ? ' + ${_selectedCustomers.length - 3} more'
                                        : ''),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: KTypography.bodySmall,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: KButton.outlined(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KButton.primary(
                      label: editing ? 'Save changes' : 'Create Beat',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
