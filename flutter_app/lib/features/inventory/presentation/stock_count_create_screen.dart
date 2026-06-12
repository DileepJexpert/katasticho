import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/k_keyboard_form_wrapper.dart';
import '../../../routing/app_router.dart';

class StockCountCreateScreen extends ConsumerStatefulWidget {
  const StockCountCreateScreen({super.key});

  @override
  ConsumerState<StockCountCreateScreen> createState() =>
      _StockCountCreateScreenState();
}

class _StockCountCreateScreenState
    extends ConsumerState<StockCountCreateScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  // Header fields
  String? _selectedWarehouseId;
  String? _selectedWarehouseName;
  DateTime _countDate = DateTime.now();
  final _notesCtl = TextEditingController();

  // Warehouses
  List<Map<String, dynamic>> _warehouses = [];
  bool _loadingWarehouses = true;

  // Line items
  final List<_CountLine> _lines = [];

  // Item search
  final _itemSearchCtl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  @override
  void dispose() {
    _notesCtl.dispose();
    _itemSearchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouses() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.warehouses);
      final data = response.data['data'] ?? response.data;
      final list = data is List ? data : (data is Map ? (data['content'] as List?) ?? [] : []);
      _warehouses = (list as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      if (_warehouses.length == 1) {
        _selectedWarehouseId = _warehouses.first['id']?.toString();
        _selectedWarehouseName = _warehouses.first['name']?.toString();
      }
    } catch (_) {
      // Warehouses may fail — user can retry
    }
    if (mounted) setState(() => _loadingWarehouses = false);
  }

  Future<void> _searchItems(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        ApiConfig.items,
        queryParameters: {'search': query.trim()},
      );
      final data = response.data['data'] ?? response.data;
      final list = data is List ? data : (data is Map ? (data['content'] as List?) ?? [] : []);
      _searchResults = (list as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (_) {
      _searchResults = [];
    }
    if (mounted) setState(() => _isSearching = false);
  }

  void _addItem(Map<String, dynamic> item) {
    final itemId = item['id']?.toString();
    if (itemId == null) return;

    // Avoid adding duplicate items
    if (_lines.any((l) => l.itemId == itemId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item already added')),
      );
      return;
    }

    setState(() {
      _lines.add(_CountLine(
        itemId: itemId,
        itemName: item['name']?.toString() ?? item['itemName']?.toString() ?? 'Unknown',
        sku: item['sku']?.toString() ?? '',
        expectedQuantity: 0,
        countedQuantity: 0,
      ));
      _searchResults = [];
      _itemSearchCtl.clear();
    });

    // Load expected quantity for the item if warehouse is selected
    if (_selectedWarehouseId != null) {
      _loadExpectedQuantity(_lines.length - 1);
    }
  }

  Future<void> _loadExpectedQuantity(int lineIndex) async {
    if (lineIndex >= _lines.length) return;
    final line = _lines[lineIndex];
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(
        ApiConfig.itemBalances(line.itemId),
        queryParameters: {
          if (_selectedWarehouseId != null)
            'warehouseId': _selectedWarehouseId,
        },
      );
      final data = response.data['data'] ?? response.data;
      double qty = 0;
      if (data is List && data.isNotEmpty) {
        for (final balance in data) {
          if (balance is Map) {
            qty += (balance['quantityOnHand'] as num?)?.toDouble() ?? 0;
          }
        }
      } else if (data is Map) {
        qty = (data['quantityOnHand'] as num?)?.toDouble() ??
            (data['totalQuantity'] as num?)?.toDouble() ??
            0;
      }
      if (mounted) {
        setState(() {
          _lines[lineIndex].expectedQuantity = qty;
        });
      }
    } catch (_) {
      // Expected quantity stays at 0 if fetch fails
    }
  }

  void _loadAllExpectedQuantities() {
    for (var i = 0; i < _lines.length; i++) {
      _loadExpectedQuantity(i);
    }
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _countDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _countDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedWarehouseId == null) {
      setState(() => _errorMessage = 'Please select a warehouse');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _errorMessage = 'Add at least one item to count');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'warehouseId': _selectedWarehouseId,
        'countDate': _countDate.toIso8601String().split('T').first,
        if (_notesCtl.text.trim().isNotEmpty) 'notes': _notesCtl.text.trim(),
        'lines': _lines
            .map((l) => {
                  'itemId': l.itemId,
                  'countedQuantity': l.countedQuantity,
                  if (l.notes.isNotEmpty) 'notes': l.notes,
                })
            .toList(),
      };

      final response = await api.post(ApiConfig.stockCounts, data: body);
      final data = response.data['data'] ?? response.data;
      final newId = data is Map ? data['id']?.toString() : null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock count created')),
        );
        if (newId != null) {
          context.go('/inventory/stock-counts/$newId');
        } else {
          context.go(Routes.stockCounts);
        }
      }
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = 'Failed to create stock count';
      if (body is Map) {
        msg = body['message'] as String? ?? msg;
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create stock count');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardFormWrapper(
      onSubmit: _submit,
      onCancel: () => context.go(Routes.stockCounts),
      child: Scaffold(
      appBar: AppBar(
        title: const Text('New Stock Count'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.stockCounts),
        ),
      ),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          if (_errorMessage != null) ...[
            KErrorBanner(
              message: _errorMessage!,
              onDismiss: () => setState(() => _errorMessage = null),
            ),
            KSpacing.vGapMd,
          ],
          _buildHeaderSection(),
          KSpacing.vGapMd,
          _buildLinesSection(),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    ));
  }

  Widget _buildHeaderSection() {
    return KCard(
      title: 'Count Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warehouse dropdown
          Text('Warehouse', style: KTypography.labelMedium),
          KSpacing.vGapXs,
          _loadingWarehouses
              ? const SizedBox(
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: _selectedWarehouseId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Select warehouse',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _warehouses.map((wh) {
                    return DropdownMenuItem<String>(
                      value: wh['id']?.toString(),
                      child: Text(
                        wh['name']?.toString() ?? 'Unnamed',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedWarehouseId = value;
                      _selectedWarehouseName = _warehouses
                          .firstWhere(
                            (wh) => wh['id']?.toString() == value,
                            orElse: () => <String, dynamic>{},
                          )['name']
                          ?.toString();
                    });
                    _loadAllExpectedQuantities();
                  },
                ),
          KSpacing.vGapMd,

          // Count date
          Text('Count Date', style: KTypography.labelMedium),
          KSpacing.vGapXs,
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(
                DateFormatter.display(_countDate),
                style: KTypography.bodyMedium,
              ),
            ),
          ),
          KSpacing.vGapMd,

          // Notes
          KTextField(
            label: 'Notes',
            hint: 'Optional notes about this count',
            controller: _notesCtl,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildLinesSection() {
    return KCard(
      title: 'Count Lines',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item search
          TextField(
            controller: _itemSearchCtl,
            decoration: InputDecoration(
              hintText: 'Search items to add...',
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: KColors.textHint),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _itemSearchCtl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _itemSearchCtl.clear();
                            setState(() => _searchResults = []);
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
            onChanged: _searchItems,
          ),

          // Search results
          if (_searchResults.isNotEmpty) ...[
            KSpacing.vGapSm,
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: KColors.divider),
                borderRadius: KSpacing.borderRadiusMd,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  final name = item['name']?.toString() ??
                      item['itemName']?.toString() ??
                      'Unknown';
                  final sku = item['sku']?.toString() ?? '';
                  return ListTile(
                    dense: true,
                    title: Text(name, style: KTypography.labelLarge),
                    subtitle: sku.isNotEmpty
                        ? Text('SKU: $sku', style: KTypography.bodySmall)
                        : null,
                    trailing: const Icon(Icons.add_circle_outline,
                        color: KColors.primary, size: 20),
                    onTap: () => _addItem(item),
                  );
                },
              ),
            ),
          ],

          KSpacing.vGapMd,

          // Added lines
          if (_lines.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 36, color: KColors.textHint),
                    KSpacing.vGapSm,
                    Text(
                      'Search and add items to count',
                      style: KTypography.bodyMedium
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(_lines.length, (index) {
              return _CountLineCard(
                line: _lines[index],
                onCountedChanged: (value) {
                  setState(() {
                    _lines[index].countedQuantity = value;
                  });
                },
                onNotesChanged: (value) {
                  _lines[index].notes = value;
                },
                onRemove: () => _removeLine(index),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
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
                Text(
                  '${_lines.length} item${_lines.length == 1 ? '' : 's'}',
                  style: KTypography.labelLarge,
                ),
                if (_lines.isNotEmpty)
                  Text(
                    '${_lines.where((l) => l.variance != 0).length} with variance',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                  ),
              ],
            ),
            const Spacer(),
            KButton(
              label: 'Create Count',
              icon: Icons.check,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountLine {
  final String itemId;
  final String itemName;
  final String sku;
  double expectedQuantity;
  double countedQuantity;
  String notes;

  _CountLine({
    required this.itemId,
    required this.itemName,
    required this.sku,
    this.expectedQuantity = 0,
    this.countedQuantity = 0,
    this.notes = '',
  });

  double get variance => countedQuantity - expectedQuantity;
}

class _CountLineCard extends StatelessWidget {
  final _CountLine line;
  final ValueChanged<double> onCountedChanged;
  final ValueChanged<String> onNotesChanged;
  final VoidCallback onRemove;

  const _CountLineCard({
    required this.line,
    required this.onCountedChanged,
    required this.onNotesChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final variance = line.variance;
    final varianceColor = variance > 0
        ? KColors.success
        : variance < 0
            ? KColors.error
            : KColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: KColors.divider),
        borderRadius: KSpacing.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.itemName, style: KTypography.labelLarge),
                    if (line.sku.isNotEmpty) ...[
                      KSpacing.vGapXxs,
                      Text(
                        'SKU: ${line.sku}',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: KColors.textHint,
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('System Qty', style: KTypography.labelSmall),
                    KSpacing.vGapXxs,
                    Text(
                      _fmtQty(line.expectedQuantity),
                      style: KTypography.amountSmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Counted Qty', style: KTypography.labelSmall),
                    KSpacing.vGapXxs,
                    SizedBox(
                      height: 36,
                      child: TextFormField(
                        initialValue: line.countedQuantity == 0
                            ? ''
                            : _fmtQty(line.countedQuantity),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? 0;
                          onCountedChanged(parsed);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Variance', style: KTypography.labelSmall),
                    KSpacing.vGapXxs,
                    Text(
                      '${variance >= 0 ? '+' : ''}${_fmtQty(variance)}',
                      style: KTypography.amountSmall.copyWith(
                        color: varianceColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          TextField(
            decoration: const InputDecoration(
              hintText: 'Line notes (optional)',
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            style: KTypography.bodySmall,
            onChanged: onNotesChanged,
          ),
        ],
      ),
    );
  }

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}
