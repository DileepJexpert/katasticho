import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../routing/app_router.dart';
import '../../contacts/data/contact_repository.dart';
import '../../custom_fields/data/custom_field_repository.dart';
import '../../inventory/data/item_repository.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../../pricing/data/scheme_repository.dart';
import '../../settings/data/org_settings_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/sales_order_providers.dart';
import '../data/sales_order_repository.dart';
import 'widgets/atp_badge.dart';

class SalesOrderCreateScreen extends ConsumerStatefulWidget {
  const SalesOrderCreateScreen({super.key});

  @override
  ConsumerState<SalesOrderCreateScreen> createState() =>
      _SalesOrderCreateScreenState();
}

class _SalesOrderCreateScreenState extends ConsumerState<SalesOrderCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();
  final _customFieldsKey = GlobalKey<KCustomFieldsRendererState>();
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  String? _selectedContactId;
  String _contactName = '';
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _loadingCustomers = true;
  bool _allowBackorder = false;

  List<Map<String, dynamic>> _warehouses = [];
  String? _selectedWarehouseId;
  bool _loadingWarehouses = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final repo = ref.read(itemRepositoryProvider);
      final allWarehouses = await repo.listWarehouses();
      final activeWarehouses = allWarehouses.where((warehouse) {
        final active = warehouse['active'] ?? warehouse['isActive'];
        return active is! bool || active;
      }).toList();
      if (!mounted) return;
      if (activeWarehouses.isEmpty) {
        setState(() {
          _warehouses = [];
          _loadingWarehouses = false;
        });
        return;
      }
      final defaultWarehouse = activeWarehouses.firstWhere(
        (warehouse) => warehouse['isDefault'] == true,
        orElse: () => activeWarehouses.first,
      );
      setState(() {
        _warehouses = activeWarehouses;
        _selectedWarehouseId = defaultWarehouse['id']?.toString();
        _loadingWarehouses = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingWarehouses = false);
    }
  }

  Future<void> _loadCustomers() async {
    try {
      final repo = ref.read(contactRepositoryProvider);
      final result = await repo.listContacts(size: 200);
      final content = result['data'];
      final list = content is List
          ? content.cast<Map<String, dynamic>>()
          : (content is Map
              ? ((content['content'] as List?)?.cast<Map<String, dynamic>>() ??
                  [])
              : <Map<String, dynamic>>[]);
      final customers = list.where((c) {
        final type = (c['contactType'] as String? ?? '').toUpperCase();
        return type == 'CUSTOMER' || type == 'BOTH';
      }).toList();
      if (mounted) {
        setState(() {
          _customers = customers;
          _filteredCustomers = customers;
          _loadingCustomers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingCustomers = false);
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        final lower = query.toLowerCase();
        _filteredCustomers = _customers
            .where((c) =>
                (c['displayName'] as String? ?? '')
                    .toLowerCase()
                    .contains(lower) ||
                (c['companyName'] as String? ?? '')
                    .toLowerCase()
                    .contains(lower) ||
                (c['phone'] as String? ?? '').contains(lower) ||
                (c['mobile'] as String? ?? '').contains(lower) ||
                (c['gstin'] as String? ?? '').toLowerCase().contains(lower))
            .toList();
      }
    });
  }

  final List<_LineItem> _lineItems = [_LineItem()];

  DateTime _orderDate = DateTime.now();
  DateTime _expectedShipmentDate = DateTime.now().add(const Duration(days: 7));
  String _deliveryMethod = '';
  String _placeOfSupply = '';
  String _notes = '';
  String _terms = '';

  // Subtotal is the taxable amount after line discounts, before GST.
  double get _subtotal =>
      _lineItems.fold(0, (sum, line) => sum + line.taxableAmount);

  double get _totalTax =>
      _lineItems.fold(0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _totalTax;

  Future<void> _handleSubmit() async {
    // Guard: Ctrl+Enter can invoke this directly while a submit is in
    // flight; without this check a second press creates a duplicate document.
    if (_isSubmitting) return;
    if (_selectedWarehouseId == null) {
      setState(() {
        _currentStep = 1;
        _errorMessage = 'Select an active fulfilment warehouse';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(salesOrderRepositoryProvider);
      final data = {
        'contactId': _selectedContactId,
        'orderDate': _orderDate.toIso8601String().split('T')[0],
        'expectedShipmentDate':
            _expectedShipmentDate.toIso8601String().split('T')[0],
        'deliveryMethod': _deliveryMethod,
        'placeOfSupply': _placeOfSupply,
        'notes': _notes,
        'terms': _terms,
        'allowBackorder': _allowBackorder,
        'warehouseId': _selectedWarehouseId,
        'lines': _lineItems
            .where((l) => l.description.isNotEmpty)
            .map((l) => {
                  'description': l.description,
                  'hsnCode': l.hsnCode,
                  'quantity': l.quantity,
                  'rate': l.rate,
                  'unit': l.unit,
                  'discountPct': l.discountPct,
                  if (l.taxGroupId != null) 'taxGroupId': l.taxGroupId,
                  if (l.itemId != null) 'itemId': l.itemId,
                })
            .toList(),
      };

      final result = await repo.createSalesOrder(data);
      ref.invalidate(salesOrderListProvider);

      final created = (result['data'] ?? result) as Map<String, dynamic>;
      final soId = created['id']?.toString() ?? '';
      final customInputs = _customFieldsKey.currentState?.getValues();
      if (soId.isNotEmpty && customInputs != null && customInputs.isNotEmpty) {
        try {
          await ref.read(customFieldRepositoryProvider).saveValues(
            'SALES_ORDER',
            soId,
            customInputs,
          );
        } catch (e) {
          debugPrint('Failed to save custom fields on sales order: $e');
        }
      }

      if (mounted) {
        final created = (result['data'] ?? result) as Map<String, dynamic>;
        final id = created['id']?.toString();
        final status = created['status']?.toString();
        final warnings = (created['warnings'] as List<dynamic>?)
                ?.map((w) => w.toString())
                .toList() ??
            [];

        if (warnings.isNotEmpty) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded,
                  color: KColors.warning, size: 32),
              title: Text(
                status == 'PENDING_APPROVAL'
                    ? 'Order Sent for Approval'
                    : 'Order Created with Warnings',
                style: KTypography.titleMedium,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: warnings
                    .map((w) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: KSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle,
                                  size: 6, color: KColors.warning),
                              const SizedBox(width: KSpacing.sm),
                              Expanded(
                                child: Text(w,
                                    style: KTypography.bodySmall),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'PENDING_APPROVAL'
                  ? 'Sales order created and sent for approval'
                  : 'Sales order created successfully'),
            ),
          );
        }

        if (mounted) {
          if (id != null) {
            context.go('/sales-orders/$id');
          } else {
            context.go(Routes.salesOrders);
          }
        }
      }
    } catch (e) {
      if (e is DioException) {
        final fieldErrs = ApiErrorParser.fieldErrors(e);
        if (fieldErrs.isNotEmpty) {
          setState(() => serverErrors = fieldErrs);
          _formKey.currentState!.validate();
        }
        setState(() => _errorMessage = ApiErrorParser.message(e));
      } else {
        setState(() =>
            _errorMessage = 'Failed to create sales order. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _nextStep() {
    if (_currentStep >= 2) return;
    if (_currentStep == 0 && _selectedContactId == null) {
      setState(() => _errorMessage = 'Please select a customer');
      return;
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _openOrderDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _orderDate = picked);
    }
  }

  Future<void> _triggerItemPicker() async {
    if (_currentStep != 1) {
      setState(() => _currentStep = 1);
    }
    final picked = await showItemPicker(context);
    if (picked == null || !mounted) return;
    final item = _LineItem();
    item.itemId = picked['id']?.toString();
    item.description = picked['name']?.toString() ?? '';
    item.hsnCode = picked['hsnCode']?.toString() ?? '';
    item.rate = (picked['salePrice'] as num?)?.toDouble() ?? 0;
    item.unit = picked['unit']?.toString() ?? 'PCS';
    final pickedTaxGroupId = picked['defaultTaxGroupId']?.toString();
    if (pickedTaxGroupId != null) {
      item.taxGroupId = pickedTaxGroupId;
      final pickedGst = (picked['gstRate'] as num?)?.toDouble();
      item._taxRate = pickedGst ?? 0;
    }
    final baseUnit = item.unit;
    final rawSec = (picked['secondaryUnits'] as List?) ?? [];
    final secUnits = rawSec
        .map((u) => (u as Map<String, dynamic>)['uomAbbreviation']?.toString())
        .whereType<String>()
        .toList();
    item.availableUnits = [
      baseUnit,
      ...secUnits.where((u) => u != baseUnit),
    ];
    double factor = 1.0;
    String? sub;
    for (final s in rawSec) {
      if (s is Map<String, dynamic>) {
        final f = (s['conversionFactor'] as num?)?.toDouble() ?? 1.0;
        if (f > 1.0) {
          factor = f;
          sub = s['uomAbbreviation']?.toString();
          break;
        }
      }
    }
    item.conversionFactor = factor;
    item.subUnit = sub;
    setState(() {
      if (_lineItems.length == 1 &&
          _lineItems.first.itemId == null &&
          _lineItems.first.description.isEmpty) {
        _lineItems[0] = item;
      } else {
        _lineItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardFormWrapper(
      onSubmit: _currentStep == 2 ? _handleSubmit : _nextStep,
      onNextStep: _nextStep,
      onPrevStep: _prevStep,
      onCancel: () => context.go(Routes.salesOrders),
      onDateJump: _openOrderDatePicker,
      onItemPicker: _triggerItemPicker,
      onQuickCreate: _openAddCustomerSheet,
      onAddRow: () => setState(() => _lineItems.add(_LineItem())),
      onSaveAndPrint: _handleSubmit,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Create Sales Order'),
        leading: IconButton(
          tooltip: 'Back to sales orders',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.salesOrders),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _StepRail(
              currentStep: _currentStep,
              steps: const ['Customer', 'Items', 'Review'],
              onStepTap: (step) => setState(() => _currentStep = step),
            ),
            const Divider(height: 1),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: KErrorBanner(
                  message: _errorMessage!,
                  onDismiss: () => setState(() => _errorMessage = null),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: SingleChildScrollView(
                    padding: KSpacing.pagePadding,
                    child: switch (_currentStep) {
                      0 => _buildCustomerStep(),
                      1 => _buildItemsStep(),
                      2 => _buildReviewStep(),
                      _ => const SizedBox(),
                    },
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total', style: KTypography.bodySmall),
                        Text(
                          CurrencyFormatter.formatIndian(_grandTotal),
                          style: KTypography.amountLarge,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_currentStep > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: KButton(
                          label: 'Back',
                          variant: KButtonVariant.outlined,
                          onPressed: () => setState(() => _currentStep--),
                        ),
                      ),
                    if (_currentStep < 2)
                      KButton(
                        label: 'Next',
                        onPressed: _nextStep,
                      )
                    else
                      KButton(
                        label: 'Create Order',
                        onPressed: _handleSubmit,
                        isLoading: _isSubmitting,
                        icon: Icons.check,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Future<void> _openAddCustomerSheet() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddCustomerSheet(ref: ref),
    );
    if (created == null) return;
    // Reload list then auto-select the new customer
    await _loadCustomers();
    final id = created['id']?.toString() ?? '';
    final name = created['displayName'] as String? ??
        created['companyName'] as String? ??
        '';
    if (mounted && id.isNotEmpty) {
      setState(() {
        _selectedContactId = id;
        _contactName = name;
      });
    }
  }

  Widget _buildCustomerStep() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Select Customer', style: KTypography.h2),
            const Spacer(),
            TextButton.icon(
              onPressed: _openAddCustomerSheet,
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('New Customer'),
            ),
          ],
        ),
        KSpacing.vGapSm,
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: KSpacing.borderRadiusMd,
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: KTextField(
                  label: 'Search customers',
                  hint: 'Type customer name, phone or GSTIN...',
                  prefixIcon: Icons.search,
                  onChanged: _filterCustomers,
                ),
              ),
              const Divider(height: 1),
              if (_loadingCustomers)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredCustomers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _customers.isEmpty
                            ? 'No customers yet'
                            : 'No matching customers',
                        style: KTypography.bodyMedium
                            .copyWith(color: cs.onSurface),
                      ),
                      KSpacing.vGapSm,
                      KButton(
                        label: 'Add New Customer',
                        icon: Icons.person_add_outlined,
                        variant: KButtonVariant.outlined,
                        onPressed: _openAddCustomerSheet,
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 430),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(KSpacing.sm),
                    itemCount: _filteredCustomers.length,
                    separatorBuilder: (_, __) => KSpacing.vGapXs,
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      final id = customer['id']?.toString() ?? '';
                      final name = customer['displayName'] as String? ??
                          customer['companyName'] as String? ??
                          'Unknown';
                      final gstin = customer['gstin'] as String? ?? '';
                      final phone = customer['phone'] as String? ??
                          customer['mobile'] as String? ??
                          '';
                      return _CustomerSelectTile(
                        name: name,
                        gstin: gstin.isNotEmpty
                            ? 'GSTIN: $gstin'
                            : (phone.isNotEmpty ? phone : 'No details'),
                        isSelected: _selectedContactId == id,
                        onTap: () {
                          setState(() {
                            _selectedContactId = id;
                            _contactName = name;
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsStep() {
    final schemeApplyMode = ref.watch(orgSettingsProvider).maybeWhen(
          data: (settings) => _safeSchemeApplyMode(
            settings['sales.scheme_apply_mode'],
          ),
          orElse: () => 'MANUAL',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fulfilment Warehouse', style: KTypography.h2),
        KSpacing.vGapXs,
        Text(
          'Stock will be checked, reserved, and dispatched from this warehouse.',
          style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
        ),
        KSpacing.vGapSm,
        if (_loadingWarehouses)
          const KLoading(message: 'Loading warehouses...')
        else if (_warehouses.isEmpty)
          const KErrorBanner(
            message: 'No active warehouse is available for this order.',
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedWarehouseId,
            decoration: const InputDecoration(
              labelText: 'Warehouse',
              prefixIcon: Icon(Icons.warehouse_outlined),
            ),
            items: _warehouses.map((warehouse) {
              final id = warehouse['id']?.toString() ?? '';
              final name = warehouse['name']?.toString() ?? 'Warehouse';
              final code = warehouse['code']?.toString();
              final isDefault = warehouse['isDefault'] == true;
              return DropdownMenuItem(
                value: id,
                child: Text(
                  [name, if (code != null && code.isNotEmpty) code, if (isDefault) 'Default']
                      .join(' - '),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedWarehouseId = value),
          ),
        KSpacing.vGapLg,
        KBillingShortcutBar(
          onDateJump: _openOrderDatePicker,
          onItemLookup: _triggerItemPicker,
          onQuickCreate: _openAddCustomerSheet,
          onAddRow: () => setState(() => _lineItems.add(_LineItem())),
          onSubmit: _handleSubmit,
        ),
        KSpacing.vGapMd,
        Text('Line Items', style: KTypography.h2),
        KSpacing.vGapMd,
        ...List.generate(_lineItems.length, (index) {
          return _LineItemCard(
            item: _lineItems[index],
            index: index,
            schemeApplyMode: schemeApplyMode,
            warehouseId: _selectedWarehouseId,
            isLastRow: index == _lineItems.length - 1,
            onAddRow: () => setState(() => _lineItems.add(_LineItem())),
            onRemove: _lineItems.length > 1
                ? () => setState(() => _lineItems.removeAt(index))
                : null,
            onAddFreeLine: (line) => setState(
              () {
                final sourceKey = _lineItems[index].lineKey;
                _lineItems.removeWhere(
                  (item) => item.schemeSourceLineKey == sourceKey,
                );
                _lineItems.insert(index + 1, line);
              },
            ),
            onRemoveLinkedSchemeLines: () => setState(
              () => _lineItems.removeWhere(
                (item) => item.schemeSourceLineKey == _lineItems[index].lineKey,
              ),
            ),
            onChanged: () => setState(() {}),
          );
        }),
        KSpacing.vGapMd,
        KButton(
          label: 'Add Line Item',
          icon: Icons.add,
          variant: KButtonVariant.outlined,
          onPressed: () => setState(() => _lineItems.add(_LineItem())),
        ),
        KSpacing.vGapLg,
        KCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Subtotal',
                  value: CurrencyFormatter.formatIndian(_subtotal)),
              _SummaryRow(
                  label: 'Tax',
                  value: CurrencyFormatter.formatIndian(_totalTax)),
              const Divider(),
              _SummaryRow(
                label: 'Grand Total',
                value: CurrencyFormatter.formatIndian(_grandTotal),
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _safeSchemeApplyMode(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    return switch (value) {
      'AUTO' => 'AUTO',
      'DISABLED' => 'DISABLED',
      _ => 'MANUAL',
    };
  }

  Widget _buildReviewStep() {
    final selectedWarehouse = _warehouses.firstWhere(
      (warehouse) => warehouse['id']?.toString() == _selectedWarehouseId,
      orElse: () => <String, dynamic>{},
    );
    final selectedWarehouseName =
        selectedWarehouse['name']?.toString() ?? 'Not selected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Sales Order', style: KTypography.h2),
        KSpacing.vGapMd,
        KCard(
          title: 'Customer',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _contactName.isEmpty ? 'Selected Customer' : _contactName,
                style: KTypography.bodyLarge,
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          title: 'Fulfilment Warehouse',
          child: Text(
            selectedWarehouseName,
            style: KTypography.bodyLarge,
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          title: 'Dates & Delivery',
          padding: const EdgeInsets.all(KSpacing.sm),
          child: Column(
            children: [
              KCompactRow(children: [
                KDatePicker(
                  label: 'Order Date',
                  value: _orderDate,
                  onChanged: (d) => setState(() => _orderDate = d),
                ),
                KDatePicker(
                  label: 'Expected Shipment',
                  value: _expectedShipmentDate,
                  onChanged: (d) => setState(() => _expectedShipmentDate = d),
                  firstDate: _orderDate,
                ),
              ]),
              KSpacing.vGapXs,
              KCompactRow(children: [
                KTextField(
                  label: 'Delivery Method',
                  hint: 'e.g. Courier',
                  initialValue: _deliveryMethod,
                  onChanged: (v) => _deliveryMethod = v,
                ),
                KTextField(
                  label: 'Place of Supply',
                  hint: 'e.g. Maharashtra',
                  initialValue: _placeOfSupply,
                  onChanged: (v) => _placeOfSupply = v,
                ),
              ]),
            ],
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          title: 'Items (${_lineItems.length})',
          child: Column(
            children: _lineItems.asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description.isEmpty
                                ? 'Item ${entry.key + 1}'
                                : item.description,
                            style: KTypography.bodyMedium,
                          ),
                          Text(
                            '${item.quantity} x ${CurrencyFormatter.formatIndian(item.rate)}',
                            style: KTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIndian(item.lineTotal),
                      style: KTypography.amountSmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          child: Column(
            children: [
              _SummaryRow(
                  label: 'Subtotal',
                  value: CurrencyFormatter.formatIndian(_subtotal)),
              _SummaryRow(
                  label: 'Tax',
                  value: CurrencyFormatter.formatIndian(_totalTax)),
              const Divider(),
              _SummaryRow(
                label: 'Total',
                value: CurrencyFormatter.formatIndian(_grandTotal),
                bold: true,
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Allow Backorder', style: KTypography.bodyMedium),
            subtitle: Text(
              'Confirm even if stock is insufficient — backordered qty is auto-fulfilled when GRN arrives',
              style:
                  KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
            value: _allowBackorder,
            onChanged: (v) => setState(() => _allowBackorder = v),
          ),
        ),
        KSpacing.vGapSm,
        KCompactRow(children: [
          KTextField(
            label: 'Notes (optional)',
            hint: 'Add any notes',
            maxLines: 2,
            initialValue: _notes,
            onChanged: (v) => _notes = v,
          ),
          KTextField(
            label: 'Terms (optional)',
            hint: 'Terms and conditions',
            maxLines: 2,
            initialValue: _terms,
            onChanged: (v) => _terms = v,
          ),
        ]),
        KSpacing.vGapMd,
        KCustomFieldsRenderer(
          key: _customFieldsKey,
          entityType: 'SALES_ORDER',
        ),
      ],
    );
  }
}

class _LineItem {
  static int _nextLineKey = 1;

  final int lineKey = _nextLineKey++;
  String? itemId;
  String? taxGroupId;
  String description = '';
  String hsnCode = '';
  double quantity = 1;
  double rate = 0;
  String unit = 'PCS';
  double discountPct = 0;
  double _taxRate = 0;
  double conversionFactor = 1.0;
  String? subUnit;
  List<String> availableUnits = const [];
  String? appliedSchemeId;
  String? appliedSchemeName;
  bool isFreeSchemeLine = false;
  int? schemeSourceLineKey;

  double get taxableAmount {
    final base = quantity * rate;
    return base - (base * discountPct / 100);
  }

  double get taxAmount => taxableAmount * _taxRate / 100;
  double get lineTotal => taxableAmount + taxAmount;
}

class _LineItemCard extends ConsumerStatefulWidget {
  final _LineItem item;
  final int index;
  final String schemeApplyMode;
  final String? warehouseId;
  final bool isLastRow;
  final VoidCallback? onAddRow;
  final VoidCallback? onRemove;
  final ValueChanged<_LineItem> onAddFreeLine;
  final VoidCallback onRemoveLinkedSchemeLines;
  final VoidCallback onChanged;

  const _LineItemCard({
    required this.item,
    required this.index,
    required this.schemeApplyMode,
    this.warehouseId,
    this.isLastRow = false,
    this.onAddRow,
    this.onRemove,
    required this.onAddFreeLine,
    required this.onRemoveLinkedSchemeLines,
    required this.onChanged,
  });

  @override
  ConsumerState<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends ConsumerState<_LineItemCard> {
  late final TextEditingController _descCtl;
  late final TextEditingController _hsnCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _rateCtl;
  late final TextEditingController _discountCtl;

  static const _defaultUnits = [
    'PCS',
    'BOX',
    'PACK',
    'KG',
    'GM',
    'LTR',
    'ML',
    'STRIP',
    'DOZEN'
  ];

  @override
  void initState() {
    super.initState();
    _descCtl = TextEditingController(text: widget.item.description);
    _hsnCtl = TextEditingController(text: widget.item.hsnCode);
    _qtyCtl = TextEditingController(text: widget.item.quantity.toString());
    _rateCtl = TextEditingController(text: widget.item.rate.toString());
    _discountCtl =
        TextEditingController(text: widget.item.discountPct.toString());
  }

  @override
  void dispose() {
    _descCtl.dispose();
    _hsnCtl.dispose();
    _qtyCtl.dispose();
    _rateCtl.dispose();
    _discountCtl.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    _clearAppliedScheme(removeLinkedFreeLines: true);
    setState(() {
      widget.item.itemId = picked['id']?.toString();
      widget.item.description = picked['name']?.toString() ?? '';
      widget.item.hsnCode = picked['hsnCode']?.toString() ?? '';
      widget.item.rate = (picked['salePrice'] as num?)?.toDouble() ?? 0;
      widget.item.unit = picked['unit']?.toString() ?? 'PCS';
      final pickedTaxGroupId = picked['defaultTaxGroupId']?.toString();
      if (pickedTaxGroupId != null) {
        widget.item.taxGroupId = pickedTaxGroupId;
        final pickedGst = (picked['gstRate'] as num?)?.toDouble();
        widget.item._taxRate = pickedGst ?? 0;
      } else {
        widget.item.taxGroupId = null;
        widget.item._taxRate = 0;
      }

      final baseUnit = widget.item.unit;
      final secUnits = (picked['secondaryUnits'] as List?)
              ?.map((u) =>
                  (u as Map<String, dynamic>)['uomAbbreviation']?.toString())
              .whereType<String>()
              .toList() ??
          const <String>[];
      widget.item.availableUnits = [
        baseUnit,
        ...secUnits.where((u) => u != baseUnit),
      ];

      _descCtl.text = widget.item.description;
      _hsnCtl.text = widget.item.hsnCode;
      _rateCtl.text = widget.item.rate.toString();
    });
    widget.onChanged();
  }

  void _clearItemLink() {
    _clearAppliedScheme(removeLinkedFreeLines: true);
    setState(() {
      widget.item.itemId = null;
    });
    widget.onChanged();
  }

  void _clearAppliedScheme({required bool removeLinkedFreeLines}) {
    widget.item.appliedSchemeId = null;
    widget.item.appliedSchemeName = null;
    if (removeLinkedFreeLines) {
      widget.onRemoveLinkedSchemeLines();
    }
  }

  void _applyScheme(Map<String, dynamic> scheme) {
    if (widget.item.appliedSchemeId == scheme['id']?.toString()) return;

    final schemeId = scheme['id']?.toString();
    final schemeName = scheme['name']?.toString();
    final type = scheme['schemeType']?.toString();

    if (type == 'PERCENT_DISCOUNT') {
      final pct = (scheme['discountPercent'] as num?)?.toDouble() ??
          double.tryParse('${scheme['discountPercent']}') ??
          0;
      setState(() {
        widget.item.discountPct = pct;
        widget.item.appliedSchemeId = schemeId;
        widget.item.appliedSchemeName = schemeName;
        _discountCtl.text = pct == pct.roundToDouble()
            ? pct.toInt().toString()
            : pct.toStringAsFixed(2);
      });
      widget.onChanged();
      return;
    }

    if (type == 'BUY_X_GET_Y') {
      final freeQty = (scheme['freeQuantity'] as num?)?.toDouble() ??
          double.tryParse('${scheme['freeQuantity']}') ??
          0;
      if (freeQty <= 0 || widget.item.itemId == null) return;

      widget.item.appliedSchemeId = schemeId;
      widget.item.appliedSchemeName = schemeName;
      widget.onAddFreeLine(_LineItem()
        ..itemId = widget.item.itemId
        ..taxGroupId = widget.item.taxGroupId
        ..description = '${widget.item.description} (Scheme free)'
        ..hsnCode = widget.item.hsnCode
        ..quantity = freeQty
        ..rate = 0
        ..unit = widget.item.unit
        ..discountPct = 0
        .._taxRate = widget.item._taxRate
        ..availableUnits = widget.item.availableUnits
        ..appliedSchemeId = schemeId
        ..appliedSchemeName = schemeName
        ..isFreeSchemeLine = true
        ..schemeSourceLineKey = widget.item.lineKey);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLinked = widget.item.itemId != null;
    final itemId = widget.item.itemId;
    final quantity = widget.item.quantity;
    final applicableSchemes = itemId == null ||
            quantity <= 0 ||
            widget.item.isFreeSchemeLine ||
            widget.schemeApplyMode == 'DISABLED'
        ? null
        : ref.watch(applicableSchemesProvider(
            ApplicableSchemeLookup(itemId: itemId, quantity: quantity),
          ));

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.xs),
      padding: const EdgeInsets.all(KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Item ${widget.index + 1}', style: KTypography.labelLarge),
              if (isLinked) ...[
                KSpacing.hGapSm,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: KColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.link, size: 12, color: KColors.success),
                      const SizedBox(width: 4),
                      Text('Linked',
                          style: KTypography.labelSmall.copyWith(
                            color: KColors.success,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                ),
              ],
              if (widget.item.isFreeSchemeLine) ...[
                KSpacing.hGapSm,
                _LineChip(
                  icon: Icons.card_giftcard,
                  label: 'Free',
                  color: KColors.primary,
                ),
              ] else if (widget.item.appliedSchemeName != null) ...[
                KSpacing.hGapSm,
                _LineChip(
                  icon: Icons.local_offer_outlined,
                  label: 'Scheme',
                  color: KColors.primary,
                ),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: _pickItem,
                icon: const Icon(Icons.search, size: 16),
                label: Text(isLinked ? 'Change' : 'Pick Item'),
              ),
              if (isLinked)
                IconButton(
                  tooltip: 'Unlink (free-text)',
                  icon: const Icon(Icons.link_off, size: 18),
                  onPressed: _clearItemLink,
                ),
              if (widget.onRemove != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: KColors.error, size: 20),
                  onPressed: widget.onRemove,
                ),
            ],
          ),
          KSpacing.vGapXs,
          KTextField(
            label: 'Description',
            controller: _descCtl,
            onChanged: (v) {
              widget.item.description = v;
              widget.onChanged();
            },
          ),
          KSpacing.vGapXs,
          KCompactRow(children: [
            KTextField(
              label: 'HSN',
              controller: _hsnCtl,
              onChanged: (v) {
                widget.item.hsnCode = v;
                widget.onChanged();
              },
            ),
            KTextField(
              label: 'Qty',
              controller: _qtyCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                _clearAppliedScheme(removeLinkedFreeLines: true);
                widget.item.quantity = double.tryParse(v) ?? 1;
                widget.onChanged();
              },
            ),
            KTextField.amount(
              label: 'Rate',
              controller: _rateCtl,
              onChanged: (v) {
                widget.item.rate = double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ]),
          // ATP: honest available-now answer for the picked item × qty.
          // Hidden until both an item is picked AND a positive qty is typed.
          if (widget.item.itemId != null &&
              widget.warehouseId != null &&
              widget.item.quantity > 0)
            AtpBadge(
              itemId: widget.item.itemId,
              warehouseId: widget.warehouseId,
              qty: widget.item.quantity,
            ),
          KSpacing.vGapXs,
          KCompactRow(children: [
            _UnitDropdown(
              value: widget.item.unit,
              itemUnits: widget.item.availableUnits,
              onChanged: (v) {
                setState(() => widget.item.unit = v);
                widget.onChanged();
              },
            ),
            KTextField(
              label: 'Disc %',
              controller: _discountCtl,
              enabled: !widget.item.isFreeSchemeLine,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: widget.isLastRow
                  ? TextInputAction.done
                  : TextInputAction.next,
              onFieldSubmitted: (_) {
                if (widget.isLastRow) {
                  widget.onAddRow?.call();
                } else {
                  FocusScope.of(context).nextFocus();
                }
              },
              onChanged: (v) {
                _clearAppliedScheme(removeLinkedFreeLines: false);
                widget.item.discountPct = double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
            TaxGroupPicker(
              value: widget.item.taxGroupId,
              label: 'Tax',
              onChanged: (group) {
                widget.item.taxGroupId = group?.id;
                widget.item._taxRate = group?.totalRate ?? 0;
                widget.onChanged();
              },
            ),
          ]),
          if (applicableSchemes != null)
            applicableSchemes.when(
              data: (schemes) {
                if (schemes.isEmpty) return const SizedBox.shrink();
                if (widget.schemeApplyMode == 'AUTO' &&
                    widget.item.appliedSchemeId == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && widget.item.appliedSchemeId == null) {
                      _applyScheme(schemes.first);
                    }
                  });
                }
                return Padding(
                  padding: const EdgeInsets.only(top: KSpacing.xs),
                  child: _SchemeAvailabilityHint(
                    schemes: schemes,
                    appliedSchemeId: widget.item.appliedSchemeId,
                    showApplyAction: widget.schemeApplyMode == 'MANUAL',
                    onApply: _applyScheme,
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: KSpacing.xs),
                child: _SchemeAvailabilityLoading(),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          KSpacing.vGapXs,
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              CurrencyFormatter.formatIndian(widget.item.lineTotal),
              style: KTypography.amountSmall.copyWith(
                color: KColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LineChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: KTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeAvailabilityHint extends StatelessWidget {
  final List<Map<String, dynamic>> schemes;
  final String? appliedSchemeId;
  final bool showApplyAction;
  final ValueChanged<Map<String, dynamic>> onApply;

  const _SchemeAvailabilityHint({
    required this.schemes,
    required this.appliedSchemeId,
    required this.showApplyAction,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = schemes.first;
    final primaryId = primary['id']?.toString();
    final isApplied = primaryId != null && primaryId == appliedSchemeId;
    final extraCount = schemes.length - 1;
    final text = extraCount > 0
        ? '${_schemeSummary(primary)} +$extraCount more'
        : _schemeSummary(primary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: KSpacing.borderRadiusSm,
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_offer_outlined, size: 16, color: cs.tertiary),
          KSpacing.hGapXs,
          Expanded(
            child: Text(
              'Scheme available: $text',
              style: KTypography.bodySmall.copyWith(
                color: cs.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (showApplyAction || isApplied) ...[
            KSpacing.hGapXs,
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: isApplied ? null : () => onApply(primary),
              child: Text(isApplied ? 'Applied' : 'Apply'),
            ),
          ],
        ],
      ),
    );
  }

  static String _schemeSummary(Map<String, dynamic> scheme) {
    final name = scheme['name']?.toString().trim();
    final prefix = name == null || name.isEmpty ? '' : '$name - ';
    final type = scheme['schemeType']?.toString();

    if (type == 'BUY_X_GET_Y') {
      final buyQty = _quantityText(scheme['buyQuantity']);
      final freeQty = _quantityText(scheme['freeQuantity']);
      if (buyQty != null && freeQty != null) {
        return '${prefix}Buy $buyQty get $freeQty free';
      }
      if (freeQty != null) return '${prefix}Free qty $freeQty';
    }

    if (type == 'PERCENT_DISCOUNT') {
      final pct = _quantityText(scheme['discountPercent']);
      if (pct != null) return '$prefix$pct% discount';
    }

    return name == null || name.isEmpty ? 'Eligible scheme' : name;
  }

  static String? _quantityText(dynamic raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (value == null) return null;
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _SchemeAvailabilityLoading extends StatelessWidget {
  const _SchemeAvailabilityLoading();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onSurfaceVariant,
          ),
        ),
        KSpacing.hGapXs,
        Text(
          'Checking schemes...',
          style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CustomerSelectTile extends StatelessWidget {
  final String name;
  final String gstin;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomerSelectTile({
    required this.name,
    required this.gstin,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: KSpacing.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer.withValues(alpha: 0.55)
              : cs.surface,
          borderRadius: KSpacing.borderRadiusMd,
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.person,
                color: cs.primary,
                size: 19,
              ),
            ),
            KSpacing.hGapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: KTypography.bodyMedium.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  KSpacing.vGapXxs,
                  Text(
                    gstin,
                    style: KTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold ? KTypography.labelLarge : KTypography.bodyMedium,
          ),
          Text(
            value,
            style: bold ? KTypography.amountMedium : KTypography.amountSmall,
          ),
        ],
      ),
    );
  }
}

class _StepRail extends StatelessWidget {
  final int currentStep;
  final List<String> steps;
  final ValueChanged<int> onStepTap;

  const _StepRail({
    required this.currentStep,
    required this.steps,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm,
      ),
      child: Center(
        child: Wrap(
          spacing: KSpacing.sm,
          runSpacing: KSpacing.xs,
          children: [
            for (var i = 0; i < steps.length; i++)
              _StepTab(
                label: steps[i],
                index: i,
                current: currentStep,
                onTap: () => onStepTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepTab extends StatelessWidget {
  final String label;
  final int index;
  final int current;
  final VoidCallback onTap;

  const _StepTab({
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = index == current;
    final isCompleted = index < current;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? cs.primary : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isActive || isCompleted
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isCompleted
                    ? Icon(Icons.check, color: cs.onPrimary, size: 14)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
            KSpacing.hGapXs,
            Text(
              label,
              style: KTypography.labelMedium.copyWith(
                color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCustomerSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddCustomerSheet({required this.ref});

  @override
  State<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<_AddCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _error;

  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _gstinCtl = TextEditingController();

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _gstinCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final repo = widget.ref.read(contactRepositoryProvider);
      final result = await repo.createContact({
        'displayName': _nameCtl.text.trim(),
        'phone': _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
        'email': _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        'gstin': _gstinCtl.text.trim().isEmpty ? null : _gstinCtl.text.trim(),
        'contactType': 'CUSTOMER',
      });
      final data = (result['data'] ?? result) as Map<String, dynamic>;
      if (mounted) Navigator.of(context).pop(data);
    } catch (e) {
      setState(() => _error = 'Failed to create customer. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Add New Customer', style: KTypography.h2),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            KSpacing.vGapMd,
            if (_error != null) ...[
              KErrorBanner(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
              KSpacing.vGapMd,
            ],
            KTextField(
              label: 'Customer Name *',
              hint: 'Full name or company name',
              controller: _nameCtl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            KSpacing.vGapSm,
            KCompactRow(children: [
              KTextField(
                label: 'Phone',
                hint: '10-digit mobile',
                controller: _phoneCtl,
                keyboardType: TextInputType.phone,
              ),
              KTextField(
                label: 'Email',
                hint: 'optional',
                controller: _emailCtl,
                keyboardType: TextInputType.emailAddress,
              ),
            ]),
            KSpacing.vGapSm,
            KTextField(
              label: 'GSTIN (optional)',
              hint: 'e.g. 27AABCU9603R1ZX',
              controller: _gstinCtl,
            ),
            KSpacing.vGapLg,
            KButton(
              label: 'Save Customer',
              onPressed: _save,
              isLoading: _isSaving,
              fullWidth: true,
              icon: Icons.check,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  final String value;
  final List<String> itemUnits;
  final ValueChanged<String> onChanged;

  const _UnitDropdown({
    required this.value,
    required this.itemUnits,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final units =
        itemUnits.isNotEmpty ? itemUnits : _LineItemCardState._defaultUnits;

    final allUnits = units.contains(value) ? units : [value, ...units];

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Unit'),
      isExpanded: true,
      items: allUnits
          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
