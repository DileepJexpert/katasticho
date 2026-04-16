import 'package:flutter/material.dart';
import '../../../../core/widgets/widgets.dart';

/// Maps bill-specific statuses to human-readable labels and delegates
/// rendering to [KStatusChip].
///
/// Bills have these statuses: DRAFT, OPEN, OVERDUE, PARTIALLY_PAID, PAID, VOID.
class BillStatusChip extends StatelessWidget {
  final String status;
  final bool dense;

  const BillStatusChip({
    super.key,
    required this.status,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return KStatusChip(
      status: status,
      label: _label(status),
      dense: dense,
    );
  }

  static String _label(String status) {
    return switch (status) {
      'DRAFT' => 'DRAFT',
      'OPEN' => 'OPEN',
      'OVERDUE' => 'OVERDUE',
      'PARTIALLY_PAID' => 'PARTIAL',
      'PAID' => 'PAID',
      'VOID' => 'VOID',
      _ => status.replaceAll('_', ' ').toUpperCase(),
    };
  }
}
