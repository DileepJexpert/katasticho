import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/item_repository.dart';

/// Bottom sheet for recording a manual stock adjustment.
/// Wraps POST /api/v1/stock/adjust which goes through InventoryService.recordMovement().
class StockAdjustSheet extends ConsumerStatefulWidget {
  final String itemId;
  final String itemName;
  final VoidCallback? onSaved;

  const StockAdjustSheet({
    super.key,
    required this.itemId,
    required this.itemName,
    this.onSaved,
  });

  @override
  ConsumerState<StockAdjustSheet> createState() => _StockAdjustSheetState();
}

class _StockAdjustSheetState extends ConsumerState<StockAdjustSheet> {
  final _qtyController = TextEditingController();
  final _unitCostController = TextEditingController(text: '0');
  final _noteController = TextEditingController();
  String _direction = 'IN';
  bool _saving = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _unitCostController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qtyRaw = double.tryParse(_qtyController.text);
    if (qtyRaw == null || qtyRaw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a positive quantity')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final signedQty = _direction == 'IN' ? qtyRaw : -qtyRaw;
      final payload = {
        'itemId': widget.itemId,
        'quantity': signedQty,
        'unitCost': double.tryParse(_unitCostController.text) ?? 0,
        'reason': _noteController.text.trim().isEmpty
            ? 'Manual stock adjustment'
            : _noteController.text.trim(),
      };
      debugPrint('[StockAdjustSheet] adjust payload=$payload');
      await ref.read(itemRepositoryProvider).adjustStock(payload);
      widget.onSaved?.call();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock adjusted')),
      );
    } catch (e, st) {
      debugPrint('[StockAdjustSheet] FAILED: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adjustment failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: KSpacing.md,
        right: KSpacing.md,
        top: KSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Adjust Stock', style: KTypography.h2),
            KSpacing.vGapXs,
            Text(widget.itemName, style: KTypography.bodySmall),
            KSpacing.vGapMd,
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'IN',
                  label: Text('Stock In'),
                  icon: Icon(Icons.add),
                ),
                ButtonSegment(
                  value: 'OUT',
                  label: Text('Stock Out'),
                  icon: Icon(Icons.remove),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            KSpacing.vGapMd,
            KTextField(
              label: 'Quantity',
              controller: _qtyController,
              prefixIcon: Icons.numbers,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            KSpacing.vGapMd,
            KTextField.amount(
              label: 'Unit Cost (optional)',
              controller: _unitCostController,
            ),
            KSpacing.vGapMd,
            KTextField(
              label: 'Note',
              controller: _noteController,
              hint: 'Reason for adjustment',
              maxLines: 2,
            ),
            KSpacing.vGapLg,
            KButton(
              label: 'Save Adjustment',
              fullWidth: true,
              isLoading: _saving,
              onPressed: _save,
            ),
            KSpacing.vGapMd,
          ],
        ),
      ),
    );
  }
}
