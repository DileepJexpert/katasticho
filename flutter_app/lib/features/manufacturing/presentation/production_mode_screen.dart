import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';

/// Tracker #34: set an item's production mode (MTO / MTS / NONE).
class ProductionModeScreen extends ConsumerStatefulWidget {
  const ProductionModeScreen({super.key});

  @override
  ConsumerState<ProductionModeScreen> createState() =>
      _ProductionModeScreenState();
}

class _ProductionModeScreenState extends ConsumerState<ProductionModeScreen> {
  final _itemCtl = TextEditingController();
  String? _mode;
  bool _saving = false;
  String? _msg;
  Color? _msgColor;

  @override
  void dispose() {
    _itemCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _itemCtl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      await ref.read(apiClientProvider).patch(
            ApiConfig.manufacturingItemProductionMode(id),
            data: {'productionMode': _mode},
          );
      setState(() {
        _msg = _mode == null
            ? 'Cleared — item reverts to legacy (both automations).'
            : 'Set to $_mode.';
        _msgColor = KColors.success;
      });
    } catch (e) {
      setState(() {
        _msg = ApiErrorParser.message(e);
        _msgColor = KColors.error;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Production Mode (MTO / MTS)')),
      body: Padding(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How replenishment fires for this composite item:',
                      style: KTypography.labelLarge,
                    ),
                    KSpacing.vGapSm,
                    Text('• MTO — only on a sale order. Reorder sweep skips.', style: KTypography.bodySmall),
                    KSpacing.vGapXxs,
                    Text('• MTS — only when stock falls below reorder. SO→WO skips.', style: KTypography.bodySmall),
                    KSpacing.vGapXxs,
                    Text('• NONE — both automations fire (legacy default).', style: KTypography.bodySmall),
                  ],
                ),
              ),
            ),
            KSpacing.vGapMd,
            TextField(
              controller: _itemCtl,
              decoration: const InputDecoration(
                labelText: 'Item ID',
                hintText: 'UUID of the composite item',
                border: OutlineInputBorder(),
              ),
            ),
            KSpacing.vGapMd,
            Text('Production Mode', style: KTypography.titleSmall),
            KSpacing.vGapXs,
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('MTO (Make to Order)'),
                  selected: _mode == 'MTO',
                  onSelected: (_) => setState(() => _mode = 'MTO'),
                ),
                ChoiceChip(
                  label: const Text('MTS (Make to Stock)'),
                  selected: _mode == 'MTS',
                  onSelected: (_) => setState(() => _mode = 'MTS'),
                ),
                ChoiceChip(
                  label: const Text('Clear (legacy)'),
                  selected: _mode == null,
                  onSelected: (_) => setState(() => _mode = null),
                ),
              ],
            ),
            KSpacing.vGapLg,
            KButton.primary(
              onPressed: _saving ? null : _save,
              isLoading: _saving,
              icon: Icons.save,
              label: 'Save Production Mode',
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: KSpacing.md),
                child: Text(
                  _msg!,
                  style: TextStyle(color: _msgColor, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
