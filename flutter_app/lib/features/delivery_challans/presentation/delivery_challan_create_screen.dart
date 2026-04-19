import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../sales_orders/data/sales_order_repository.dart';
import '../data/delivery_challan_providers.dart';
import '../data/delivery_challan_repository.dart';

class DeliveryChallanCreateScreen extends ConsumerStatefulWidget {
  final String? salesOrderId;

  const DeliveryChallanCreateScreen({super.key, this.salesOrderId});

  @override
  ConsumerState<DeliveryChallanCreateScreen> createState() =>
      _DeliveryChallanCreateScreenState();
}

class _DeliveryChallanCreateScreenState
    extends ConsumerState<DeliveryChallanCreateScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 0: Sales Order selection
  List<Map<String, dynamic>> _salesOrders = [];
  bool _loadingOrders = true;
  String? _selectedSoId;
  Map<String, dynamic>? _selectedSo;

  // Step 1: Lines to ship
  List<_ShipLine> _shipLines = [];

  // Step 2: Delivery details
  final _vehicleCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();
  final _deliveryMethodCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.salesOrderId != null) {
      _selectedSoId = widget.salesOrderId;
      _loadSalesOrderDetail(widget.salesOrderId!);
    } else {
      _loadSalesOrders();
    }
  }

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _trackingCtrl.dispose();
    _deliveryMethodCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSalesOrders() async {
    try {
      final repo = ref.read(salesOrderRepositoryProvider);
      final result = await repo.listSalesOrders(page: 0, size: 100);
      final data = result['data'] ?? result;
      final content = data is List
          ? data.cast<Map<String, dynamic>>()
          : ((data as Map<String, dynamic>)['content'] as List?)
                  ?.cast<Map<String, dynamic>>() ??
              [];
      final shippable = content.where((so) {
        final status = so['status'] as String? ?? '';
        return status == 'CONFIRMED' || status == 'PARTIALLY_SHIPPED';
      }).toList();
      if (mounted) {
        setState(() {
          _salesOrders = shippable;
          _loadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadSalesOrderDetail(String soId) async {
    setState(() => _loadingOrders = true);
    try {
      final repo = ref.read(salesOrderRepositoryProvider);
      final result = await repo.getSalesOrder(soId);
      final so = (result['data'] ?? result) as Map<String, dynamic>;
      _populateLines(so);
      if (mounted) {
        setState(() {
          _selectedSo = so;
          _loadingOrders = false;
          if (widget.salesOrderId != null) _currentStep = 1;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  void _populateLines(Map<String, dynamic> so) {
    final lines = (so['lines'] as List?) ?? [];
    _shipLines = lines
        .map((l) {
          final line = l as Map<String, dynamic>;
          final ordered = (line['quantity'] as num?)?.toDouble() ?? 0;
          final shipped = (line['quantityShipped'] as num?)?.toDouble() ?? 0;
          final remaining = ordered - shipped;
          if (remaining <= 0) return null;
          return _ShipLine(
            soLineId: line['id']?.toString() ?? '',
            itemName: line['itemName'] as String? ??
                line['description'] as String? ??
                'Item',
            description: line['description'] as String? ?? '',
            ordered: ordered,
            alreadyShipped: shipped,
            remaining: remaining,
            shipQty: remaining,
            included: true,
          );
        })
        .whereType<_ShipLine>()
        .toList();
  }

  void _selectSalesOrder(Map<String, dynamic> so) {
    final id = so['id']?.toString();
    if (id == null) return;
    _selectedSoId = id;
    _selectedSo = so;
    _loadSalesOrderDetail(id);
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0:
        return _selectedSo != null;
      case 1:
        return _shipLines.any((l) => l.included && l.shipQty > 0);
      case 2:
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final lines = _shipLines
        .where((l) => l.included && l.shipQty > 0)
        .map((l) => {
              'soLineId': l.soLineId,
              'quantity': l.shipQty,
            })
        .toList();

    final body = <String, dynamic>{
      'salesOrderId': _selectedSoId,
      'lines': lines,
      if (_vehicleCtrl.text.trim().isNotEmpty)
        'vehicleNumber': _vehicleCtrl.text.trim(),
      if (_trackingCtrl.text.trim().isNotEmpty)
        'trackingNumber': _trackingCtrl.text.trim(),
      if (_deliveryMethodCtrl.text.trim().isNotEmpty)
        'deliveryMethod': _deliveryMethodCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    try {
      final repo = ref.read(deliveryChallanRepositoryProvider);
      final result = await repo.createDeliveryChallan(body);
      final data = (result['data'] ?? result) as Map<String, dynamic>;
      final newId = data['id']?.toString();

      ref.invalidate(deliveryChallanListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery challan created')),
        );
        if (newId != null) {
          context.go('/delivery-challans/$newId');
        } else {
          context.go('/delivery-challans');
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create challan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Delivery Challan')),
      body: Column(
        children: [
          _StepIndicator(current: _currentStep),
          Expanded(
            child: _loadingOrders
                ? const KLoading(message: 'Loading...')
                : IndexedStack(
                    index: _currentStep,
                    children: [
                      _buildStep0(),
                      _buildStep1(),
                      _buildStep2(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Step 0: Select Sales Order ─────────────────────────────

  Widget _buildStep0() {
    if (_salesOrders.isEmpty && !_loadingOrders) {
      return const KEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No shippable orders',
        subtitle: 'Only confirmed or partially shipped orders can be shipped',
      );
    }

    return ListView.builder(
      padding: KSpacing.pagePadding,
      itemCount: _salesOrders.length,
      itemBuilder: (context, index) {
        final so = _salesOrders[index];
        final soNum = so['salesOrderNumber'] as String? ?? '--';
        final customer = so['contactName'] as String? ?? 'Customer';
        final status = so['status'] as String? ?? '';
        final total = (so['total'] as num?)?.toDouble() ?? 0;
        final isSelected = so['id']?.toString() == _selectedSoId;

        return KCard(
          margin: const EdgeInsets.only(bottom: KSpacing.sm),
          borderColor: isSelected ? KColors.primary : null,
          onTap: () => _selectSalesOrder(so),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(soNum, style: KTypography.labelLarge),
                        KSpacing.hGapSm,
                        KStatusChip(status: status),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(customer, style: KTypography.bodyMedium),
                  ],
                ),
              ),
              Text(CurrencyFormatter.formatIndian(total),
                  style: KTypography.amountSmall),
            ],
          ),
        );
      },
    );
  }

  // ── Step 1: Select lines to ship ───────────────────────────

  Widget _buildStep1() {
    if (_shipLines.isEmpty) {
      return const KEmptyState(
        icon: Icons.check_circle_outline,
        title: 'All lines fully shipped',
        subtitle: 'No remaining items to ship for this order',
      );
    }

    return ListView.builder(
      padding: KSpacing.pagePadding,
      itemCount: _shipLines.length,
      itemBuilder: (context, index) {
        final line = _shipLines[index];
        return KCard(
          margin: const EdgeInsets.only(bottom: KSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: line.included,
                    onChanged: (v) {
                      setState(() => _shipLines[index] =
                          line.copyWith(included: v ?? true));
                    },
                  ),
                  Expanded(
                    child: Text(line.itemName, style: KTypography.bodyMedium),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (line.description.isNotEmpty &&
                        line.description != line.itemName)
                      Text(line.description,
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary)),
                    KSpacing.vGapXs,
                    Row(
                      children: [
                        Text(
                          'Ordered: ${_fmtQty(line.ordered)}  '
                          'Shipped: ${_fmtQty(line.alreadyShipped)}  '
                          'Remaining: ${_fmtQty(line.remaining)}',
                          style: KTypography.labelSmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                    KSpacing.vGapSm,
                    Row(
                      children: [
                        const Text('Ship Qty: '),
                        SizedBox(
                          width: 100,
                          child: KTextField(
                            label: '',
                            initialValue: _fmtQty(line.shipQty),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (v) {
                              final qty =
                                  (double.tryParse(v) ?? 0).clamp(0, line.remaining);
                              setState(() => _shipLines[index] =
                                  line.copyWith(shipQty: qty.toDouble()));
                            },
                          ),
                        ),
                        KSpacing.hGapSm,
                        TextButton(
                          onPressed: () {
                            setState(() => _shipLines[index] =
                                line.copyWith(shipQty: line.remaining));
                          },
                          child: const Text('Max'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Step 2: Delivery Details ───────────────────────────────

  Widget _buildStep2() {
    final soNum = _selectedSo?['salesOrderNumber'] as String? ?? '--';
    final customer = _selectedSo?['contactName'] as String? ?? 'Customer';
    final includedLines =
        _shipLines.where((l) => l.included && l.shipQty > 0).toList();

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KCard(
            child: Column(
              children: [
                KDetailRow(label: 'Sales Order', value: soNum),
                KDetailRow(label: 'Customer', value: customer),
                KDetailRow(
                    label: 'Lines to ship',
                    value: '${includedLines.length} items'),
              ],
            ),
          ),
          KSpacing.vGapMd,
          Text('Shipping Details', style: KTypography.h3),
          KSpacing.vGapSm,
          KTextField(
            label: 'Vehicle Number',
            hint: 'e.g. KA-01-AB-1234',
            controller: _vehicleCtrl,
            prefixIcon: Icons.local_shipping,
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Tracking Number',
            hint: 'Enter tracking/AWB number',
            controller: _trackingCtrl,
            prefixIcon: Icons.qr_code,
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Delivery Method',
            hint: 'e.g. Courier, Hand Delivery',
            controller: _deliveryMethodCtrl,
            prefixIcon: Icons.delivery_dining,
          ),
          KSpacing.vGapSm,
          KTextField(
            label: 'Notes',
            hint: 'Any special instructions',
            controller: _notesCtrl,
            maxLines: 3,
          ),
          KSpacing.vGapLg,
          Text('Items Being Shipped', style: KTypography.h3),
          KSpacing.vGapSm,
          ...includedLines.map((l) => KCard(
                margin: const EdgeInsets.only(bottom: KSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.itemName, style: KTypography.bodyMedium),
                          if (l.description.isNotEmpty &&
                              l.description != l.itemName)
                            Text(l.description,
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text('Qty: ${_fmtQty(l.shipQty)}',
                        style: KTypography.labelMedium),
                  ],
                ),
              )),
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
            if (_currentStep > 0)
              KButton(
                label: 'Back',
                variant: KButtonVariant.outlined,
                onPressed: _prevStep,
              ),
            const Spacer(),
            KButton(
              label: _currentStep == 2 ? 'Create Challan' : 'Next',
              icon: _currentStep == 2 ? Icons.check : Icons.arrow_forward,
              onPressed: _canProceed ? _nextStep : null,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtQty(double qty) {
    return qty == qty.roundToDouble()
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }
}

class _ShipLine {
  final String soLineId;
  final String itemName;
  final String description;
  final double ordered;
  final double alreadyShipped;
  final double remaining;
  final double shipQty;
  final bool included;

  _ShipLine({
    required this.soLineId,
    required this.itemName,
    required this.description,
    required this.ordered,
    required this.alreadyShipped,
    required this.remaining,
    required this.shipQty,
    required this.included,
  });

  _ShipLine copyWith({double? shipQty, bool? included}) {
    return _ShipLine(
      soLineId: soLineId,
      itemName: itemName,
      description: description,
      ordered: ordered,
      alreadyShipped: alreadyShipped,
      remaining: remaining,
      shipQty: shipQty ?? this.shipQty,
      included: included ?? this.included,
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _labels = ['Select Order', 'Ship Lines', 'Details'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: cs.surface,
      child: Row(
        children: List.generate(3, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done
                          ? cs.primary
                          : cs.outlineVariant,
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? cs.primary
                        : active
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: done
                        ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                        : Text(
                            '${i + 1}',
                            style: KTypography.labelSmall.copyWith(
                              color: active
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                if (i < 2)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: done
                          ? cs.primary
                          : cs.outlineVariant,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
