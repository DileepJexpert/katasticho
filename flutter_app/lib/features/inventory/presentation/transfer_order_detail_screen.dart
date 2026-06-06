import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';

class TransferOrderDetailScreen extends ConsumerStatefulWidget {
  const TransferOrderDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<TransferOrderDetailScreen> createState() =>
      _TransferOrderDetailScreenState();
}

class _TransferOrderDetailScreenState
    extends ConsumerState<TransferOrderDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _order;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchOrder();
  }

  Future<void> _fetchOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.transferOrderById(widget.id));
      final data = response.data['data'] ?? response.data;
      _order = data is Map<String, dynamic> ? data : null;
    } on DioException catch (e) {
      final body = e.response?.data;
      _error = (body is Map ? body['message'] as String? : null) ??
          'Failed to load transfer order';
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doAction(String label, Future<void> Function() action) async {
    setState(() => _actionInProgress = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label successful')),
        );
        _fetchOrder();
      }
    } on DioException catch (e) {
      if (mounted) {
        final body = e.response?.data;
        final msg = (body is Map ? body['message'] as String? : null) ??
            '$label failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _ship() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ship Transfer Order'),
        content: const Text(
          'This will deduct stock from the source warehouse. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ship'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = ref.read(apiClientProvider);
    await _doAction('Ship', () async {
      await api.post(ApiConfig.shipTransferOrder(widget.id));
    });
  }

  Future<void> _receive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receive Transfer Order'),
        content: const Text(
          'This will add stock to the destination warehouse. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Receive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = ref.read(apiClientProvider);
    await _doAction('Receive', () async {
      await api.post(ApiConfig.receiveTransferOrder(widget.id));
    });
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Transfer Order'),
        content: Text(
          _order?['status'] == 'IN_TRANSIT'
              ? 'This will reverse the stock deduction from the source warehouse. Continue?'
              : 'Are you sure you want to cancel this transfer order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final api = ref.read(apiClientProvider);
    await _doAction('Cancel', () async {
      await api.post(ApiConfig.cancelTransferOrder(widget.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_order?['transferNumber'] ?? 'Transfer Order'),
        actions: _buildActions(),
      ),
      body: _buildBody(),
    );
  }

  List<Widget> _buildActions() {
    if (_order == null) return [];
    final status = _order!['status'] as String? ?? '';

    final actions = <Widget>[];
    if (status == 'DRAFT') {
      actions.add(
        FilledButton.icon(
          onPressed: _actionInProgress ? null : _ship,
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          label: const Text('Ship'),
        ),
      );
      actions.add(const SizedBox(width: 8));
      actions.add(
        OutlinedButton(
          onPressed: _actionInProgress ? null : _cancel,
          child: const Text('Cancel'),
        ),
      );
    } else if (status == 'IN_TRANSIT') {
      actions.add(
        FilledButton.icon(
          onPressed: _actionInProgress ? null : _receive,
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          label: const Text('Receive'),
        ),
      );
      actions.add(const SizedBox(width: 8));
      actions.add(
        OutlinedButton(
          onPressed: _actionInProgress ? null : _cancel,
          child: const Text('Cancel'),
        ),
      );
    }
    if (actions.isNotEmpty) {
      actions.add(const SizedBox(width: KSpacing.md));
    }
    return actions;
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: KLoading());
    if (_error != null) {
      return Center(child: KErrorView(message: _error!, onRetry: _fetchOrder));
    }
    if (_order == null) {
      return const Center(
        child: KEmptyState(
          icon: Icons.swap_horiz_outlined,
          title: 'Transfer order not found',
        ),
      );
    }

    final status = _order!['status'] as String? ?? '';
    final lines = (_order!['lines'] as List<dynamic>?) ?? [];

    return RefreshIndicator(
      onRefresh: _fetchOrder,
      child: ListView(
        padding: const EdgeInsets.all(KSpacing.md),
        children: [
          _buildHeader(status),
          const SizedBox(height: KSpacing.md),
          if (status == 'IN_TRANSIT')
            Container(
              padding: const EdgeInsets.all(KSpacing.sm),
              margin: const EdgeInsets.only(bottom: KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping, color: KColors.warning, size: 20),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: Text(
                      'Items are in transit. Receive to add stock to the destination warehouse.',
                      style: KTypography.bodySmall.copyWith(color: KColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Line Items (${lines.length})',
            style: KTypography.titleMedium,
          ),
          const SizedBox(height: KSpacing.sm),
          ...lines.map((line) => _buildLineCard(line as Map<String, dynamic>)),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(KSpacing.lg),
              child: KEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No line items',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(String status) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _order!['transferNumber'] ?? '',
                    style: KTypography.titleLarge,
                  ),
                ),
                KStatusChip(status: status),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            _infoRow(
              Icons.warehouse_outlined,
              'From',
              _order!['fromWarehouseName'] ?? 'Unknown',
            ),
            const SizedBox(height: KSpacing.xs),
            _infoRow(
              Icons.warehouse,
              'To',
              _order!['toWarehouseName'] ?? 'Unknown',
            ),
            const SizedBox(height: KSpacing.xs),
            _infoRow(
              Icons.calendar_today_outlined,
              'Date',
              _formatDate(_order!['transferDate']),
            ),
            if (_order!['shippedAt'] != null) ...[
              const SizedBox(height: KSpacing.xs),
              _infoRow(
                Icons.local_shipping_outlined,
                'Shipped',
                _formatDateTime(_order!['shippedAt']),
              ),
            ],
            if (_order!['receivedAt'] != null) ...[
              const SizedBox(height: KSpacing.xs),
              _infoRow(
                Icons.check_circle_outline,
                'Received',
                _formatDateTime(_order!['receivedAt']),
              ),
            ],
            if (_order!['notes'] != null &&
                (_order!['notes'] as String).isNotEmpty) ...[
              const Divider(height: KSpacing.lg),
              Text(
                _order!['notes'] as String,
                style: KTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: KSpacing.sm),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: KTypography.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: KTypography.bodyMedium),
        ),
      ],
    );
  }

  Widget _buildLineCard(Map<String, dynamic> line) {
    final qty = _parseNum(line['quantity']);
    final receivedQty = _parseNum(line['receivedQuantity']);
    final status = _order!['status'] as String? ?? '';

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line['itemName'] ?? 'Unknown Item',
                        style: KTypography.titleSmall,
                      ),
                      if (line['sku'] != null)
                        Text(
                          line['sku'] as String,
                          style: KTypography.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Qty: ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}',
                      style: KTypography.titleSmall,
                    ),
                    if (status == 'RECEIVED')
                      Text(
                        'Received: ${receivedQty.toStringAsFixed(receivedQty.truncateToDouble() == receivedQty ? 0 : 2)}',
                        style: KTypography.bodySmall.copyWith(
                          color: KColors.success,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (line['batchNumber'] != null) ...[
              const SizedBox(height: KSpacing.xs),
              Row(
                children: [
                  Icon(Icons.layers_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Batch: ${line['batchNumber']}',
                    style: KTypography.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            if (line['notes'] != null &&
                (line['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: KSpacing.xs),
              Text(
                line['notes'] as String,
                style: KTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? '-' : DateFormatter.display(date);
  }

  String _formatDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? '-' : DateFormatter.dateTime(date);
  }
}
