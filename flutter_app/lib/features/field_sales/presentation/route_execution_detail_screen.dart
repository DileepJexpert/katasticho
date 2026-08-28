import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/field_sales_repository.dart';
import 'k_merchandising_capture_sheet.dart';

class RouteExecutionDetailScreen extends ConsumerStatefulWidget {
  const RouteExecutionDetailScreen({super.key, required this.executionId});
  final String executionId;

  @override
  ConsumerState<RouteExecutionDetailScreen> createState() =>
      _RouteExecutionDetailScreenState();
}

class _RouteExecutionDetailScreenState
    extends ConsumerState<RouteExecutionDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _execution;
  List<Map<String, dynamic>> _visits = [];
  double? _currentLat;
  double? _currentLng;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _currentLat = pos.latitude;
          _currentLng = pos.longitude;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.getExecution(widget.executionId),
        repo.getVisits(widget.executionId),
      ]);
      if (mounted) {
        setState(() {
          _execution = results[0] as Map<String, dynamic>;
          _visits = (results[1] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load execution: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double? _calculateDistance(double? targetLat, double? targetLng) {
    if (_currentLat == null ||
        _currentLng == null ||
        targetLat == null ||
        targetLng == null) {
      return null;
    }
    const earthRadius = 6371000.0; // meters
    final dLat = (targetLat - _currentLat!) * math.pi / 180.0;
    final dLng = (targetLng - _currentLng!) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_currentLat! * math.pi / 180.0) *
            math.cos(targetLat * math.pi / 180.0) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _checkIn(String visitId) async {
    try {
      final pos = await LocationService.getCurrentPosition();
      final lat = pos?.latitude ?? _currentLat ?? 0;
      final lng = pos?.longitude ?? _currentLng ?? 0;
      if (pos == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location unavailable — using last known coordinates'),
          ),
        );
      }
      await ref
          .read(fieldSalesRepositoryProvider)
          .checkIn(visitId, lat, lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked in successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check in: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _checkOut(String visitId) async {
    final notesCtl = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check Out Visit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete this visit and record closing remarks.',
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
            KSpacing.vGapSm,
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(
                labelText: 'Visit Notes',
                hintText: 'Customer feedback, next visit plan, or remarks',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, true),
            label: 'Complete & Check Out',
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    try {
      final pos = await LocationService.getCurrentPosition();
      final lat = pos?.latitude ?? _currentLat ?? 0;
      final lng = pos?.longitude ?? _currentLng ?? 0;
      final notes = notesCtl.text.trim();
      await ref.read(fieldSalesRepositoryProvider).checkOut(
            visitId,
            lat,
            lng,
            notes: notes.isNotEmpty ? notes : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checked out successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to check out: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showSkipDialog(String visitId) async {
    final reasonCtl = TextEditingController();
    String selectedReason = 'Shop Closed';

    final presetReasons = [
      'Shop Closed',
      'Owner Not Available',
      'Stock Full / No Order',
      'Payment Dispute',
      'Order Postponed',
      'Other',
    ];

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: KSpacing.md,
            right: KSpacing.md,
            top: KSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.skip_next_rounded, color: KColors.warning),
                  KSpacing.hGapSm,
                  Text('Skip Visit', style: KTypography.h3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              Text(
                'Select a reason for skipping this scheduled customer visit:',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapSm,
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: presetReasons.map((r) {
                  final isSel = selectedReason == r;
                  return ChoiceChip(
                    label: Text(r),
                    selected: isSel,
                    selectedColor: KColors.primarySoft,
                    onSelected: (v) {
                      if (v) setModalState(() => selectedReason = r);
                    },
                  );
                }).toList(),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: reasonCtl,
                decoration: const InputDecoration(
                  labelText: 'Additional Remarks (Optional)',
                  hintText: 'Provide additional details...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              KSpacing.vGapMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KButton.outlined(
                    size: KButtonSize.small,
                    onPressed: () => Navigator.pop(ctx, false),
                    label: 'Cancel',
                  ),
                  KSpacing.hGapSm,
                  KButton.danger(
                    size: KButtonSize.small,
                    label: 'Confirm Skip',
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != true || !mounted) return;

    final combinedReason = reasonCtl.text.trim().isNotEmpty
        ? '$selectedReason: ${reasonCtl.text.trim()}'
        : selectedReason;

    try {
      await ref
          .read(fieldSalesRepositoryProvider)
          .skipVisit(visitId, combinedReason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit skipped'),
            backgroundColor: KColors.warning,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to skip visit: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showRecordOrderDialog(String visitId) async {
    final orderValueCtl = TextEditingController();
    final salesOrderIdCtl = TextEditingController();
    double currentVal = 0;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: KSpacing.md,
            right: KSpacing.md,
            top: KSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: KColors.primary),
                  KSpacing.hGapSm,
                  Text('Record Visit Order', style: KTypography.h3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              Text(
                'Enter the total booked order value and optional Sales Order number.',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapMd,
              KTextField.amount(
                controller: orderValueCtl,
                label: 'Order Total Value *',
                hint: 'e.g. 15000',
                autofocus: true,
                onChanged: (v) {
                  setModalState(() {
                    currentVal = double.tryParse(v.trim()) ?? 0;
                  });
                },
              ),
              if (currentVal > 0) ...[
                KSpacing.vGapXs,
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Amount: ', style: KTypography.bodySmall),
                      KMoney(currentVal, size: KMoneySize.small),
                    ],
                  ),
                ),
              ],
              KSpacing.vGapSm,
              KTextField(
                controller: salesOrderIdCtl,
                label: 'Sales Order ID / Ref #',
                hint: 'Optional SO-XXXX',
              ),
              KSpacing.vGapMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KButton.outlined(
                    size: KButtonSize.small,
                    onPressed: () => Navigator.pop(ctx, false),
                    label: 'Cancel',
                  ),
                  KSpacing.hGapSm,
                  KButton.primary(
                    size: KButtonSize.small,
                    label: 'Save Order',
                    onPressed: () {
                      if (orderValueCtl.text.trim().isEmpty || currentVal <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid order amount'),
                            backgroundColor: KColors.error,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != true || !mounted) return;

    try {
      final value = double.tryParse(orderValueCtl.text.trim()) ?? 0;
      await ref.read(fieldSalesRepositoryProvider).recordOrder(
            visitId,
            salesOrderIdCtl.text.trim(),
            value,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order recorded successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record order: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showRecordCollectionDialog(String visitId) async {
    final amountCtl = TextEditingController();
    String paymentMode = 'CASH';
    double currentAmt = 0;

    final paymentModes = [
      {'key': 'CASH', 'label': 'Cash', 'icon': Icons.money},
      {'key': 'UPI', 'label': 'UPI / QR', 'icon': Icons.qr_code_2},
      {'key': 'CHEQUE', 'label': 'Cheque', 'icon': Icons.receipt_long},
      {'key': 'BANK_TRANSFER', 'label': 'NEFT/IMPS', 'icon': Icons.account_balance},
    ];

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: KSpacing.md,
            right: KSpacing.md,
            top: KSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_outlined, color: KColors.success),
                  KSpacing.hGapSm,
                  Text('Record Payment Collection', style: KTypography.h3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              Text(
                'Record payments received on-site against outstanding invoices.',
                style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapSm,
              Wrap(
                spacing: KSpacing.xs,
                runSpacing: KSpacing.xs,
                children: paymentModes.map((m) {
                  final isSel = paymentMode == m['key'];
                  return ChoiceChip(
                    avatar: Icon(m['icon'] as IconData, size: 16),
                    label: Text(m['label'] as String),
                    selected: isSel,
                    selectedColor: KColors.primarySoft,
                    onSelected: (v) {
                      if (v) setModalState(() => paymentMode = m['key'] as String);
                    },
                  );
                }).toList(),
              ),
              KSpacing.vGapMd,
              KTextField.amount(
                controller: amountCtl,
                label: 'Collected Amount *',
                hint: 'e.g. 5000',
                autofocus: true,
                onChanged: (v) {
                  setModalState(() {
                    currentAmt = double.tryParse(v.trim()) ?? 0;
                  });
                },
              ),
              if (currentAmt > 0) ...[
                KSpacing.vGapXs,
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Amount: ', style: KTypography.bodySmall),
                      KMoney(currentAmt, size: KMoneySize.small),
                    ],
                  ),
                ),
              ],
              KSpacing.vGapMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KButton.outlined(
                    size: KButtonSize.small,
                    onPressed: () => Navigator.pop(ctx, false),
                    label: 'Cancel',
                  ),
                  KSpacing.hGapSm,
                  KButton.primary(
                    size: KButtonSize.small,
                    label: 'Save Collection',
                    onPressed: () {
                      if (amountCtl.text.trim().isEmpty || currentAmt <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid collection amount'),
                            backgroundColor: KColors.error,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != true || !mounted) return;

    try {
      final amount = double.tryParse(amountCtl.text.trim()) ?? 0;
      await ref
          .read(fieldSalesRepositoryProvider)
          .recordCollection(visitId, amount);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collection recorded successfully'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record collection: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  void _openShelfAudit(Map<String, dynamic> visit) {
    final visitId = visit['id']?.toString() ?? '';
    final contactId = visit['contactId']?.toString() ?? '';
    final customerName = visit['customerName']?.toString() ?? 'Customer';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KMerchandisingCaptureSheet(
        fieldVisitId: visitId,
        routeExecutionId: widget.executionId,
        contactId: contactId,
        customerName: customerName,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _completeRoute() async {
    try {
      await ref
          .read(fieldSalesRepositoryProvider)
          .completeExecution(widget.executionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route marked completed'),
            backgroundColor: KColors.success,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete route: ${ApiErrorParser.message(e)}'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Execution Detail')),
        body: const Center(child: KLoading(message: 'Loading execution details...')),
      );
    }

    if (_execution == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Execution Detail')),
        body: const Center(child: Text('No data found')),
      );
    }

    final exec = _execution!;
    final status = exec['status']?.toString() ?? 'PLANNED';
    final routeName = exec['routeName']?.toString() ??
        exec['routeId']?.toString() ??
        '--';
    final salesperson = exec['salespersonName']?.toString() ??
        exec['salespersonId']?.toString() ??
        '--';
    final execDate = exec['date']?.toString() ?? '--';
    final vanReg = exec['vanRegistrationNumber']?.toString() ??
        exec['vanVehicleNumber']?.toString();
    final totalVisits = (exec['totalVisits'] as num?)?.toInt() ?? _visits.length;
    final completedVisits = (exec['completedVisits'] as num?)?.toInt() ??
        _visits.where((v) => v['status'] == 'COMPLETED').length;
    final skippedVisits = (exec['skippedVisits'] as num?)?.toInt() ??
        _visits.where((v) => v['status'] == 'SKIPPED').length;
    final ordersTotal = (exec['ordersValue'] as num?)?.toDouble() ?? 0;
    final collectionsTotal = (exec['collections'] as num?)?.toDouble() ?? 0;

    final double completionRatio =
        totalVisits > 0 ? (completedVisits / totalVisits).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Execution Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadData();
              _fetchCurrentLocation();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadData();
          await _fetchCurrentLocation();
        },
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // -- Header Section --
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          routeName,
                          style: KTypography.h4.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      KStatusChip(
                        status: status,
                        label: status.replaceAll('_', ' '),
                      ),
                    ],
                  ),
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: KColors.textSecondary),
                      KSpacing.hGapXs,
                      Text(
                        execDate,
                        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                      ),
                      KSpacing.hGapMd,
                      const Icon(Icons.person_outline, size: 14, color: KColors.textSecondary),
                      KSpacing.hGapXs,
                      Expanded(
                        child: Text(
                          salesperson,
                          style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (vanReg != null) ...[
                        KSpacing.hGapMd,
                        const Icon(Icons.local_shipping_outlined, size: 14, color: KColors.textSecondary),
                        KSpacing.hGapXs,
                        Text(
                          vanReg,
                          style: KTypography.mono(fontSize: 12, color: KColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  KSpacing.vGapSm,
                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Visit Progress',
                            style: KTypography.labelSmall.copyWith(color: KColors.textSecondary),
                          ),
                          Text(
                            '$completedVisits / $totalVisits (${(completionRatio * 100).toStringAsFixed(0)}%)',
                            style: KTypography.labelSmall.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completionRatio,
                          minHeight: 6,
                          backgroundColor: KColors.divider,
                          valueColor: const AlwaysStoppedAnimation<Color>(KColors.success),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            KSpacing.vGapMd,

            // -- Metrics Wrap --
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                _SummaryCard(
                  label: 'Planned',
                  value: '$totalVisits',
                  color: KColors.info,
                ),
                _SummaryCard(
                  label: 'Completed',
                  value: '$completedVisits',
                  color: KColors.success,
                ),
                _SummaryCard(
                  label: 'Skipped',
                  value: '$skippedVisits',
                  color: KColors.warning,
                ),
                _SummaryCard(
                  label: 'Orders Total',
                  valueWidget: KMoney(
                    ordersTotal,
                    size: KMoneySize.small,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  color: KColors.primary,
                ),
                _SummaryCard(
                  label: 'Collections Total',
                  valueWidget: KMoney(
                    collectionsTotal,
                    size: KMoneySize.small,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: KColors.success,
                    ),
                  ),
                  color: KColors.success,
                ),
              ],
            ),
            KSpacing.vGapMd,

            // -- Visits Section --
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scheduled Visits (${_visits.length})', style: KTypography.h4),
                if (_currentLat != null && _currentLng != null)
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 14, color: KColors.success),
                      const SizedBox(width: 4),
                      Text('GPS Active', style: KTypography.labelSmall.copyWith(color: KColors.success)),
                    ],
                  ),
              ],
            ),
            KSpacing.vGapSm,
            if (_visits.isEmpty)
              const KCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No customer visits planned on this route execution.'),
                  ),
                ),
              )
            else
              ..._visits.map((visit) {
                final visitId = visit['id']?.toString() ?? '';
                final contactName = visit['contactName']?.toString() ??
                    visit['contactId']?.toString() ??
                    'Customer';
                final contactPhone = visit['contactPhone']?.toString();
                final contactAddress = visit['contactAddress']?.toString();
                final targetLat = (visit['latitude'] as num?)?.toDouble() ??
                    (visit['customerLatitude'] as num?)?.toDouble();
                final targetLng = (visit['longitude'] as num?)?.toDouble() ??
                    (visit['customerLongitude'] as num?)?.toDouble();
                final seq = (visit['sequence'] as num?)?.toInt() ??
                    (visit['sequenceNumber'] as num?)?.toInt();
                final visitStatus = visit['status']?.toString() ?? 'PLANNED';
                final checkInTime = visit['checkInTime']?.toString();
                final checkOutTime = visit['checkOutTime']?.toString();
                final orderValue = (visit['orderValue'] as num?)?.toDouble();
                final collectionAmount =
                    (visit['collectionAmount'] as num?)?.toDouble();
                final skipReason = visit['skipReason']?.toString();

                final distanceM = _calculateDistance(targetLat, targetLng);

                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: KCard(
                    statusAccent: KColors.statusColor(visitStatus),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Visit Row Header
                        Row(
                          children: [
                            if (seq != null) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: KColors.statusBgColor(visitStatus),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    '$seq',
                                    style: KTypography.labelMedium.copyWith(
                                      color: KColors.statusColor(visitStatus),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              KSpacing.hGapSm,
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contactName,
                                    style: KTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (contactPhone != null || contactAddress != null)
                                    Text(
                                      [contactPhone, contactAddress]
                                          .where((e) => e != null && e.isNotEmpty)
                                      .join(' • '),
                                      style: KTypography.bodySmall.copyWith(
                                        color: KColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            KStatusChip(
                              status: visitStatus,
                              label: visitStatus.replaceAll('_', ' '),
                            ),
                          ],
                        ),

                        // Geofence & Location Distance Indicator
                        if (distanceM != null) ...[
                          KSpacing.vGapXs,
                          Row(
                            children: [
                              Icon(
                                distanceM <= 250
                                    ? Icons.check_circle_outline
                                    : Icons.near_me_outlined,
                                size: 14,
                                color: distanceM <= 250
                                    ? KColors.success
                                    : KColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                distanceM < 1000
                                    ? '${distanceM.toStringAsFixed(0)}m away ${distanceM <= 250 ? "(Within geofence)" : "(Outside 250m geofence)"}'
                                    : '${(distanceM / 1000).toStringAsFixed(1)}km away',
                                style: KTypography.bodySmall.copyWith(
                                  color: distanceM <= 250
                                      ? KColors.success
                                      : KColors.warning,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Completed / In-Progress Details
                        if (checkInTime != null ||
                            checkOutTime != null ||
                            orderValue != null ||
                            collectionAmount != null) ...[
                          KSpacing.vGapSm,
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: KColors.bgApp,
                              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (checkInTime != null)
                                  Text(
                                    'In: ${checkInTime.length > 16 ? checkInTime.substring(11, 16) : checkInTime}',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                  ),
                                if (checkOutTime != null)
                                  Text(
                                    'Out: ${checkOutTime.length > 16 ? checkOutTime.substring(11, 16) : checkOutTime}',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                                  ),
                                if (orderValue != null && orderValue > 0)
                                  Row(
                                    children: [
                                      Text('Order: ', style: KTypography.labelSmall),
                                      KMoney(orderValue, size: KMoneySize.small),
                                    ],
                                  ),
                                if (collectionAmount != null && collectionAmount > 0)
                                  Row(
                                    children: [
                                      Text('Col: ', style: KTypography.labelSmall),
                                      KMoney(collectionAmount, size: KMoneySize.small),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],

                        // Skipped visit details
                        if (visitStatus == 'SKIPPED' &&
                            skipReason != null &&
                            skipReason.isNotEmpty) ...[
                          KSpacing.vGapSm,
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: KColors.warningLight,
                              borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 14, color: KColors.warning),
                                KSpacing.hGapXs,
                                Expanded(
                                  child: Text(
                                    'Skipped: $skipReason',
                                    style: KTypography.bodySmall.copyWith(color: KColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Action Buttons
                        KSpacing.vGapSm,
                        Wrap(
                          spacing: KSpacing.sm,
                          runSpacing: KSpacing.xs,
                          children: [
                            if (visitStatus == 'PLANNED') ...[
                              KButton.primary(
                                label: 'Check In',
                                icon: Icons.location_on,
                                size: KButtonSize.small,
                                onPressed: () => _checkIn(visitId),
                              ),
                              KButton.outlined(
                                label: 'Skip Visit',
                                icon: Icons.skip_next_outlined,
                                size: KButtonSize.small,
                                onPressed: () => _showSkipDialog(visitId),
                              ),
                            ],
                            if (visitStatus == 'IN_PROGRESS') ...[
                              KButton.primary(
                                label: 'Check Out',
                                icon: Icons.check_circle_outline,
                                size: KButtonSize.small,
                                onPressed: () => _checkOut(visitId),
                              ),
                              KButton.outlined(
                                label: '+ Order',
                                icon: Icons.shopping_bag_outlined,
                                size: KButtonSize.small,
                                onPressed: () => _showRecordOrderDialog(visitId),
                              ),
                              KButton.outlined(
                                label: '+ Collection',
                                icon: Icons.payments_outlined,
                                size: KButtonSize.small,
                                onPressed: () =>
                                    _showRecordCollectionDialog(visitId),
                              ),
                              KButton.outlined(
                                label: 'Shelf Audit',
                                icon: Icons.camera_alt_outlined,
                                size: KButtonSize.small,
                                onPressed: () => _openShelfAudit(visit),
                              ),
                            ],
                            if (visitStatus == 'COMPLETED') ...[
                              KButton.outlined(
                                label: '+ Add Order',
                                icon: Icons.shopping_bag_outlined,
                                size: KButtonSize.small,
                                onPressed: () => _showRecordOrderDialog(visitId),
                              ),
                              KButton.outlined(
                                label: '+ Add Collection',
                                icon: Icons.payments_outlined,
                                size: KButtonSize.small,
                                onPressed: () =>
                                    _showRecordCollectionDialog(visitId),
                              ),
                              KButton.outlined(
                                label: 'Shelf Audit',
                                icon: Icons.camera_alt_outlined,
                                size: KButtonSize.small,
                                onPressed: () => _openShelfAudit(visit),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            KSpacing.vGapLg,
          ],
        ),
      ),
      bottomNavigationBar: (status == 'IN_PROGRESS' || status == 'COMPLETED')
          ? Container(
              padding: KSpacing.pagePadding,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: const Border(
                  top: BorderSide(color: KColors.divider),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (status == 'IN_PROGRESS')
                      Expanded(
                        child: KButton.primary(
                          label: 'Complete All Route Visits',
                          icon: Icons.done_all,
                          size: KButtonSize.large,
                          onPressed: _completeRoute,
                        ),
                      ),
                    if (status == 'COMPLETED')
                      Expanded(
                        child: KButton.primary(
                          label: 'Proceed to Day Close',
                          icon: Icons.nightlight_outlined,
                          size: KButtonSize.large,
                          onPressed: () => context.push(
                            '/field-sales/day-close?executionId=${widget.executionId}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color color;

  const _SummaryCard({
    required this.label,
    this.value,
    this.valueWidget,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      statusAccent: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: KTypography.labelSmall),
          const SizedBox(height: 4),
          valueWidget ??
              Text(
                value ?? '',
                style: KTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
        ],
      ),
    );
  }
}
