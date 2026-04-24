import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../routing/app_router.dart';
import '../../contacts/data/contact_repository.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../../tax_groups/data/tax_group_repository.dart';
import '../../tax_groups/presentation/widgets/tax_group_picker.dart';
import '../data/sales_order_providers.dart';
import '../data/sales_order_repository.dart';

class SalesOrderCreateScreen extends ConsumerStatefulWidget {
  const SalesOrderCreateScreen({super.key});

  @override
  ConsumerState<SalesOrderCreateScreen> createState() =>
      _SalesOrderCreateScreenState();
}

class _SalesOrderCreateScreenState
    extends ConsumerState<SalesOrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  String? _selectedContactId;
  String _contactName = '';
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _loadingCustomers = true;
  String _customerSearch = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final repo = ref.read(contactRepositoryProvider);
      final result = await repo.listContacts(size: 200);
      final content = result['data'];
      final list = content is List
          ? content.cast<Map<String, dynamic>>()
          : (content is Map
              ? ((content['content'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [])
              : <Map<String, dynamic>>[]);
      final customers = list
          .where((c) {
            final type = (c['contactType'] as String? ?? '').toUpperCase();
            return type == 'CUSTOMER' || type == 'BOTH';
          })
          .toList();
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
      _customerSearch = query;
      if (query.isEmpty) {
        _filteredCustomers = _customers;
      } else {
        final lower = query.toLowerCase();
        _filteredCustomers = _customers
            .where((c) =>
                (c['displayName'] as String? ?? '').toLowerCase().contains(lower) ||
                (c['companyName'] as String? ?? '').toLowerCase().contains(lower) ||
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

  double get _subtotal =>
      _lineItems.fold(0, (sum, line) => sum + line.lineTotal);

  double get _totalTax =>
      _lineItems.fold(0, (sum, line) => sum + line.taxAmount);

  double get _grandTotal => _subtotal + _totalTax;

  Future<void> _handleSubmit() async {
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

      if (mounted) {
        final created = (result['data'] ?? result) as Map<String, dynamic>;
        final id = created['id']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sales order created successfully')),
        );
        if (id != null) {
          context.go('/sales-orders/$id');
        } else {
          context.go(Routes.salesOrders);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e is DioException
            ? ApiErrorParser.message(e)
            : 'Failed to create sales order. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Sales Order'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go(Routes.salesOrders),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              color: KColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StepTab(
                    label: 'Customer',
                    index: 0,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 0),
                  ),
                  _stepConnector(),
                  _StepTab(
                    label: 'Items',
                    index: 1,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 1),
                  ),
                  _stepConnector(),
                  _StepTab(
                    label: 'Review',
                    index: 2,
                    current: _currentStep,
                    onTap: () => setState(() => _currentStep = 2),
                  ),
                ],
              ),
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
                          onPressed: () =>
                              setState(() => _currentStep--),
                        ),
                      ),
                    if (_currentStep < 2)
                      KButton(
                        label: 'Next',
                        onPressed: () {
                          if (_currentStep == 0 &&
                              _selectedContactId == null) {
                            setState(() =>
                                _errorMessage = 'Please select a customer');
                            return;
                          }
                          setState(() => _currentStep++);
                        },
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
    );
  }

  Widget _stepConnector() {
    return Container(
      width: 32,
      height: 2,
      color: KColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildCustomerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Customer', style: KTypography.h2),
        KSpacing.vGapMd,

        KTextField(
          label: 'Search customers',
          hint: 'Type customer name, phone or GSTIN...',
          prefixIcon: Icons.search,
          onChanged: _filterCustomers,
        ),
        KSpacing.vGapMd,

        Text(
          'Your Customers',
          style: KTypography.labelLarge.copyWith(color: KColors.textSecondary),
        ),
        KSpacing.vGapSm,

        if (_loadingCustomers)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (_filteredCustomers.isEmpty)
          _CustomerSelectTile(
            name: _customers.isEmpty
                ? 'No customers yet'
                : 'No matching customers',
            gstin: _customers.isEmpty
                ? 'Add customers from the Customers tab first'
                : 'Try a different search term',
            isSelected: false,
            onTap: () {},
          )
        else
          ..._filteredCustomers.map((customer) {
            final id = customer['id']?.toString() ?? '';
            final name = customer['displayName'] as String? ??
                customer['companyName'] as String? ?? 'Unknown';
            final gstin = customer['gstin'] as String? ?? '';
            final phone = customer['phone'] as String? ??
                customer['mobile'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CustomerSelectTile(
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
              ),
            );
          }),
      ],
    );
  }

  Widget _buildItemsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Line Items', style: KTypography.h2),
        KSpacing.vGapMd,

        ...List.generate(_lineItems.length, (index) {
          return _LineItemCard(
            item: _lineItems[index],
            index: index,
            onRemove: _lineItems.length > 1
                ? () => setState(() => _lineItems.removeAt(index))
                : null,
            onChanged: () => setState(() {}),
          );
        }),

        KSpacing.vGapMd,
        KButton(
          label: 'Add Line Item',
          icon: Icons.add,
          variant: KButtonVariant.outlined,
          onPressed: () =>
              setState(() => _lineItems.add(_LineItem())),
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

  Widget _buildReviewStep() {
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
                  onChanged: (d) =>
                      setState(() => _expectedShipmentDate = d),
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
      ],
    );
  }
}

class _LineItem {
  String? itemId;
  String? taxGroupId;
  String description = '';
  String hsnCode = '';
  double quantity = 1;
  double rate = 0;
  String unit = 'PCS';
  double discountPct = 0;
  double _taxRate = 0;

  double get taxableAmount {
    final base = quantity * rate;
    return base - (base * discountPct / 100);
  }

  double get taxAmount => taxableAmount * _taxRate / 100;
  double get lineTotal => taxableAmount + taxAmount;
}

class _LineItemCard extends StatefulWidget {
  final _LineItem item;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  const _LineItemCard({
    required this.item,
    required this.index,
    this.onRemove,
    required this.onChanged,
  });

  @override
  State<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends State<_LineItemCard> {
  late final TextEditingController _descCtl;
  late final TextEditingController _hsnCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _rateCtl;
  late final TextEditingController _unitCtl;
  late final TextEditingController _discountCtl;

  @override
  void initState() {
    super.initState();
    _descCtl = TextEditingController(text: widget.item.description);
    _hsnCtl = TextEditingController(text: widget.item.hsnCode);
    _qtyCtl = TextEditingController(text: widget.item.quantity.toString());
    _rateCtl = TextEditingController(text: widget.item.rate.toString());
    _unitCtl = TextEditingController(text: widget.item.unit);
    _discountCtl =
        TextEditingController(text: widget.item.discountPct.toString());
  }

  @override
  void dispose() {
    _descCtl.dispose();
    _hsnCtl.dispose();
    _qtyCtl.dispose();
    _rateCtl.dispose();
    _unitCtl.dispose();
    _discountCtl.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    setState(() {
      widget.item.itemId = picked['id']?.toString();
      widget.item.description = picked['name']?.toString() ?? '';
      widget.item.hsnCode = picked['hsnCode']?.toString() ?? '';
      widget.item.rate = (picked['salePrice'] as num?)?.toDouble() ?? 0;
      widget.item.unit = picked['unit']?.toString() ?? 'PCS';
      final pickedTaxGroupId = picked['taxGroupId']?.toString();
      if (pickedTaxGroupId != null) {
        widget.item.taxGroupId = pickedTaxGroupId;
      }
      final pickedGst = (picked['gstRate'] as num?)?.toDouble();
      if (pickedGst != null) {
        widget.item._taxRate = pickedGst;
      }
      _descCtl.text = widget.item.description;
      _hsnCtl.text = widget.item.hsnCode;
      _rateCtl.text = widget.item.rate.toString();
      _unitCtl.text = widget.item.unit;
    });
    widget.onChanged();
  }

  void _clearItemLink() {
    setState(() {
      widget.item.itemId = null;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isLinked = widget.item.itemId != null;
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          KSpacing.vGapXs,
          KCompactRow(children: [
            KTextField(
              label: 'Unit',
              controller: _unitCtl,
              onChanged: (v) {
                widget.item.unit = v;
                widget.onChanged();
              },
            ),
            KTextField(
              label: 'Disc %',
              controller: _discountCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
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
    return InkWell(
      onTap: onTap,
      borderRadius: KSpacing.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? KColors.primary.withValues(alpha: 0.06)
              : KColors.surface,
          borderRadius: KSpacing.borderRadiusMd,
          border: Border.all(
            color: isSelected ? KColors.primary : KColors.divider,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: KColors.primaryLight.withValues(alpha: 0.15),
              child: Icon(
                Icons.person,
                color: KColors.primary,
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: KTypography.bodyMedium),
                  Text(gstin, style: KTypography.bodySmall),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: KColors.primary),
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
    final isActive = index == current;
    final isCompleted = index < current;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive || isCompleted
                  ? KColors.primary
                  : KColors.divider,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : KColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
          KSpacing.hGapXs,
          Text(
            label,
            style: KTypography.labelMedium.copyWith(
              color: isActive ? KColors.primary : KColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
