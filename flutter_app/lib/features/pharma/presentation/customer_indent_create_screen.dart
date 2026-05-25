import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../../inventory/presentation/item_picker_sheet.dart';
import '../data/customer_indent_repository.dart';

class CustomerIndentCreateScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? prefill;

  const CustomerIndentCreateScreen({super.key, this.prefill});

  @override
  ConsumerState<CustomerIndentCreateScreen> createState() =>
      _CustomerIndentCreateScreenState();
}

class _CustomerIndentCreateScreenState
    extends ConsumerState<CustomerIndentCreateScreen> {
  Map<String, dynamic>? _contact;
  Map<String, dynamic>? _item;
  DateTime? _neededBy;
  bool _submitting = false;
  String? _error;

  final _customerCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _qtyCtl = TextEditingController(text: '1');
  final _notesCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefill = widget.prefill;
    if (prefill != null) {
      final item = prefill['item'];
      if (item is Map<String, dynamic>) {
        _item = item;
      }
      _customerCtl.text = prefill['customerName']?.toString() ?? '';
      _phoneCtl.text = prefill['customerPhone']?.toString() ?? '';
      final contactId = prefill['contactId']?.toString();
      if (contactId != null && contactId.isNotEmpty) {
        _contact = {
          'id': contactId,
          'displayName': _customerCtl.text,
          'phone': _phoneCtl.text,
        };
      }
    }
  }

  @override
  void dispose() {
    _customerCtl.dispose();
    _phoneCtl.dispose();
    _qtyCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickCustomer() async {
    final picked = await showContactPicker(context, showQuickCreate: true);
    if (picked == null) return;
    setState(() {
      _contact = picked;
      _customerCtl.text = _contactName(picked);
      _phoneCtl.text = picked['phone']?.toString() ??
          picked['mobile']?.toString() ??
          _phoneCtl.text;
    });
  }

  Future<void> _pickItem() async {
    final picked = await showItemPicker(context);
    if (picked == null) return;
    setState(() => _item = picked);
  }

  Future<void> _submit() async {
    if (_item == null) {
      setState(() => _error = 'Please select an item');
      return;
    }
    if (_customerCtl.text.trim().isEmpty) {
      setState(() => _error = 'Customer name is required');
      return;
    }
    final qty = double.tryParse(_qtyCtl.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _error = 'Quantity must be greater than zero');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final body = {
        if (_contact?['id'] != null) 'contactId': _contact!['id'],
        'customerName': _customerCtl.text.trim(),
        if (_phoneCtl.text.trim().isNotEmpty)
          'customerPhone': _phoneCtl.text.trim(),
        'itemId': _item!['id'],
        'quantity': qty,
        'source': widget.prefill == null ? 'MANUAL' : 'POS',
        if (_neededBy != null)
          'neededBy': _neededBy!.toIso8601String().split('T').first,
        if (_notesCtl.text.trim().isNotEmpty) 'notes': _notesCtl.text.trim(),
      };
      await ref.read(customerIndentRepositoryProvider).create(body);
      ref.invalidate(customerIndentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer indent created')),
        );
        context.go(Routes.customerIndents);
      }
    } catch (e) {
      String message = 'Failed to create customer indent';
      if (e is DioException && e.response?.data is Map) {
        final data = e.response!.data as Map;
        message = data['message']?.toString() ?? message;
      }
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemName = _item?['name']?.toString();
    final itemSku = _item?['sku']?.toString();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to customer indents',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.customerIndents),
        ),
        title: const Text('New Customer Indent'),
      ),
      body: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              KErrorBanner(
                message: _error!,
                onDismiss: () => setState(() => _error = null),
              ),
              KSpacing.vGapMd,
            ],
            Text('Customer', style: KTypography.h3),
            KSpacing.vGapSm,
            KCard(
              onTap: _pickCustomer,
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.person_search_outlined,
                      color: KColors.primary),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      _contact == null
                          ? 'Pick existing customer or type below'
                          : _contactName(_contact!),
                      style: KTypography.labelLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            KSpacing.vGapSm,
            KTextField(label: 'Customer Name', controller: _customerCtl),
            KSpacing.vGapSm,
            KTextField(
              label: 'Phone (optional)',
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
            ),
            KSpacing.vGapLg,
            Text('Item Requested', style: KTypography.h3),
            KSpacing.vGapSm,
            KCard(
              onTap: _pickItem,
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.medication_outlined, color: KColors.primary),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName ?? 'Pick item',
                          style: KTypography.labelLarge,
                        ),
                        if (itemSku != null && itemSku.isNotEmpty)
                          Text('SKU $itemSku', style: KTypography.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            KSpacing.vGapSm,
            KTextField(
              label: 'Quantity',
              controller: _qtyCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            KSpacing.vGapSm,
            KDatePicker(
              label: 'Needed By (optional)',
              value: _neededBy ?? DateTime.now().add(const Duration(days: 2)),
              onChanged: (value) => setState(() => _neededBy = value),
            ),
            KSpacing.vGapSm,
            KTextField(
              label: 'Notes (optional)',
              controller: _notesCtl,
              maxLines: 3,
            ),
            KSpacing.vGapXl,
            Row(
              children: [
                Expanded(
                  child: KButton(
                    label: 'Create Indent',
                    icon: Icons.save_outlined,
                    isLoading: _submitting,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _contactName(Map<String, dynamic> contact) {
    for (final key in const [
      'displayName',
      'companyName',
      'name',
      'fullName'
    ]) {
      final value = contact[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Customer';
  }
}
