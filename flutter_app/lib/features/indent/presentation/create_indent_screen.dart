import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../data/indent_repository.dart';

class CreateIndentScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? prefilledItem;

  const CreateIndentScreen({super.key, this.prefilledItem});

  @override
  ConsumerState<CreateIndentScreen> createState() => _CreateIndentScreenState();
}

class _CreateIndentScreenState extends ConsumerState<CreateIndentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _itemSearchController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  Map<String, dynamic>? _selectedItem;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isSubmitting = false;
  Timer? _debounce;
  DateTime? _promisedDate;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledItem != null) {
      _selectedItem = widget.prefilledItem;
      _itemSearchController.text = widget.prefilledItem!['name'] ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _itemSearchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.posSearch,
          queryParameters: {'q': query, 'limit': 10});
      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(res.data ?? []);
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectItem(Map<String, dynamic> item) {
    setState(() {
      _selectedItem = item;
      _itemSearchController.text = item['name'] ?? '';
      _searchResults = [];
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an item')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(indentRepositoryProvider);
      await repo.create({
        'itemId': _selectedItem!['id'],
        'itemName': _selectedItem!['name'],
        'sku': _selectedItem!['sku'],
        'contactName': _customerNameController.text.trim().isEmpty
            ? null
            : _customerNameController.text.trim(),
        'contactPhone': _customerPhoneController.text.trim().isEmpty
            ? null
            : _customerPhoneController.text.trim(),
        'requestedQty': double.tryParse(_qtyController.text) ?? 1,
        'unit': _selectedItem!['unit'] ?? 'PCS',
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'promisedDate': _promisedDate?.toIso8601String().split('T').first,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Indent created'),
            backgroundColor: KColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create indent: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Customer Indent')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Item', style: KTypography.labelMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _itemSearchController,
              decoration: InputDecoration(
                hintText: 'Search item by name, SKU, or barcode',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _selectedItem != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _selectedItem = null;
                            _itemSearchController.clear();
                            _searchResults = [];
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _selectedItem == null ? _onSearchChanged : null,
              readOnly: _selectedItem != null,
              validator: (_) =>
                  _selectedItem == null ? 'Please select an item' : null,
            ),
            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = _searchResults[i];
                    final stock =
                        (item['currentStock'] as num?)?.toDouble() ?? 0;
                    return ListTile(
                      dense: true,
                      title: Text(item['name'] ?? '',
                          style: KTypography.labelMedium),
                      subtitle: Text(
                        '${item['sku'] ?? ''} • Stock: ${stock.toStringAsFixed(0)}',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                      trailing: stock <= 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: KColors.errorLight,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Out of stock',
                                  style: KTypography.labelSmall.copyWith(
                                      color: KColors.error, fontSize: 10)),
                            )
                          : null,
                      onTap: () => _selectItem(item),
                    );
                  },
                ),
              ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(8),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (_selectedItem != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 20, color: KColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedItem!['name'] ?? '',
                              style: KTypography.labelMedium),
                          Text(
                            'SKU: ${_selectedItem!['sku'] ?? 'N/A'} • Stock: ${(_selectedItem!['currentStock'] as num?)?.toStringAsFixed(0) ?? '0'}',
                            style: KTypography.bodySmall
                                .copyWith(color: KColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            KSpacing.vGapLg,
            Text('Customer Details', style: KTypography.labelMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                hintText: 'Customer name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerPhoneController,
              decoration: const InputDecoration(
                hintText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            KSpacing.vGapLg,
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quantity', style: KTypography.labelMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _qtyController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = double.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Invalid quantity';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Promised Date', style: KTypography.labelMedium),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 2)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 90)),
                          );
                          if (date != null) {
                            setState(() => _promisedDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            suffixIcon:
                                Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            _promisedDate != null
                                ? '${_promisedDate!.day}/${_promisedDate!.month}/${_promisedDate!.year}'
                                : 'Select date',
                            style: _promisedDate != null
                                ? null
                                : TextStyle(color: KColors.textHint),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            KSpacing.vGapLg,
            Text('Notes', style: KTypography.labelMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Optional notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            KSpacing.vGapXl,
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Create Indent'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
