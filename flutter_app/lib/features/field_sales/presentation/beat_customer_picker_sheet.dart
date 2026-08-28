import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../../contacts/data/contact_repository.dart';

/// Selects the customer stops for a beat without loading the entire contact
/// master into the client. The API search stays responsive as the org grows.
Future<List<Map<String, dynamic>>?> showBeatCustomerPickerSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> selectedCustomers,
}) {
  return showModalBottomSheet<List<Map<String, dynamic>>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BeatCustomerPickerSheet(
      selectedCustomers: selectedCustomers,
    ),
  );
}

class _BeatCustomerPickerSheet extends ConsumerStatefulWidget {
  const _BeatCustomerPickerSheet({required this.selectedCustomers});

  final List<Map<String, dynamic>> selectedCustomers;

  @override
  ConsumerState<_BeatCustomerPickerSheet> createState() =>
      _BeatCustomerPickerSheetState();
}

class _BeatCustomerPickerSheetState
    extends ConsumerState<_BeatCustomerPickerSheet> {
  static const _pageSize = 30;

  final _searchController = TextEditingController();
  final Map<String, Map<String, dynamic>> _selectedById = {};

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _customers = [];
  String _query = '';
  int _nextPage = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    for (final customer in widget.selectedCustomers) {
      // Beat assignments have their own id; the picker must retain the contact id.
      final id = customer['contactId']?.toString() ?? customer['id']?.toString();
      if (id != null && id.isNotEmpty) {
        _selectedById[id] = _normaliseCustomer(customer, id: id);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomers());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers({bool loadMore = false}) async {
    if (loadMore && (!_hasMore || _isLoadingMore || _isLoading)) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _nextPage = 0;
        _hasMore = true;
      }
    });

    try {
      final response = await ref.read(contactRepositoryProvider).listContacts(
            page: _nextPage,
            size: _pageSize,
            type: 'CUSTOMER',
            search: _query.isEmpty ? null : _query,
          );
      final wrapped = response['data'] ?? response;
      final page = wrapped is Map
          ? wrapped.cast<String, dynamic>()
          : <String, dynamic>{};
      final rawContent = page['content'];
      final customers = rawContent is List
          ? rawContent
              .whereType<Map>()
              .map((row) => row.cast<String, dynamic>())
              .where((customer) => customer['active'] != false)
              .toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _customers = loadMore ? [..._customers, ...customers] : customers;
        _nextPage += 1;
        _hasMore = page['last'] != true && customers.length == _pageSize;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load customers: ${ApiErrorParser.message(error)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _loadCustomers();
    });
  }

  void _toggleCustomer(Map<String, dynamic> customer) {
    final id = customer['id']?.toString();
    if (id == null || id.isEmpty) return;

    setState(() {
      if (_selectedById.containsKey(id)) {
        _selectedById.remove(id);
      } else {
        _selectedById[id] = _normaliseCustomer(customer, id: id);
      }
    });
  }

  Map<String, dynamic> _normaliseCustomer(
    Map<String, dynamic> customer, {
    required String id,
  }) {
    return {
      ...customer,
      'id': id,
      'displayName': customer['displayName'] ?? customer['contactName'],
    };
  }

  String _customerName(Map<String, dynamic> customer) {
    return customer['displayName']?.toString() ??
        customer['contactName']?.toString() ??
        customer['companyName']?.toString() ??
        'Unnamed customer';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedById.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, sheetController) => Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KSpacing.radiusLg),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.md,
                KSpacing.lg,
                KSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Select customer stops',
                        style: KTypography.titleLarge),
                  ),
                  KStatusChip(
                    status: selectedCount == 0 ? 'PENDING' : 'ACTIVE',
                    label: '$selectedCount selected',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: KTextField.search(
                controller: _searchController,
                hint: 'Search customers by name, phone or GSTIN',
                onChanged: _onSearchChanged,
                onClear: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
            ),
            KSpacing.vGapSm,
            Expanded(
              child: _isLoading
                  ? const KLoading()
                  : _customers.isEmpty
                      ? KEmptyState(
                          icon: Icons.people_outline,
                          title: _query.isEmpty
                              ? 'No active customers found'
                              : 'No matching customers',
                          subtitle: _query.isEmpty
                              ? 'Create a customer contact before assigning this beat.'
                              : 'Try a name, phone number or GSTIN.',
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.extentAfter < 240 &&
                                _hasMore &&
                                !_isLoading &&
                                !_isLoadingMore) {
                              _loadCustomers(loadMore: true);
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: sheetController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.lg,
                              vertical: KSpacing.xs,
                            ),
                            itemCount: _customers.length +
                                (_isLoadingMore || _hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                            if (index == _customers.length) {
                              if (_isLoadingMore) {
                                return const Padding(
                                  padding: EdgeInsets.all(KSpacing.md),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.all(KSpacing.sm),
                                child: Center(
                                  child: KButton.outlined(
                                    label: 'Load more customers',
                                    size: KButtonSize.small,
                                    onPressed: () => _loadCustomers(loadMore: true),
                                  ),
                                ),
                              );
                            }

                            final customer = _customers[index];
                            final id = customer['id']?.toString() ?? '';
                            final isSelected = _selectedById.containsKey(id);
                            final phone = customer['phone']?.toString();
                            final company = customer['companyName']?.toString();
                            final gstin = customer['gstin']?.toString();
                            final infoParts = [company, phone].where((v) => v != null && v.isNotEmpty).join(' • ');

                            return KCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: KSpacing.sm,
                                vertical: KSpacing.xs,
                              ),
                              onTap: () => _toggleCustomer(customer),
                              child: CheckboxListTile(
                                value: isSelected,
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: KSpacing.xs,
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.trailing,
                                title: Text(_customerName(customer),
                                    style: KTypography.labelLarge),
                                subtitle: (infoParts.isEmpty && (gstin == null || gstin.isEmpty))
                                    ? null
                                    : Row(
                                        children: [
                                          if (infoParts.isNotEmpty)
                                            Flexible(
                                              child: Text(
                                                infoParts,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: KTypography.bodySmall.copyWith(
                                                  color: KColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          if (gstin != null && gstin.isNotEmpty) ...[
                                            if (infoParts.isNotEmpty)
                                              Text(' • ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                                            Text(
                                              gstin,
                                              style: KTypography.mono(
                                                fontSize: 11,
                                                color: KColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                onChanged: (_) => _toggleCustomer(customer),
                              ),
                            );
                            },
                          ),
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.lg),
                child: Row(
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
                        label: 'Use $selectedCount customer${selectedCount == 1 ? '' : 's'}',
                        onPressed: () => Navigator.pop(
                          context,
                          _selectedById.values.toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
