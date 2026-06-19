import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// Tracker #34: set an item's production mode (MTO / MTS / NONE).
///
/// Two replenishment automations now read this flag:
/// - MTO  — only the SO→WO path fires for this item (reorder sweep skips).
/// - MTS  — only the reorder sweep fires (SO→WO skips).
/// - NONE — legacy: both fire (existing behaviour for unset items).
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
        _msgColor = Colors.green;
      });
    } catch (e) {
      setState(() {
        _msg = ApiErrorParser.message(e);
        _msgColor = Colors.red;
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
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('How replenishment fires for this composite item:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 6),
                    Text('• MTO — only on a sale order. Reorder sweep skips.'),
                    Text('• MTS — only when stock falls below reorder. SO→WO skips.'),
                    Text('• NONE — both automations fire (legacy default).'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            TextField(
              controller: _itemCtl,
              decoration: const InputDecoration(
                labelText: 'Item id',
                helperText: 'UUID of the composite item',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Text('Production mode', style: KTypography.titleSmall),
            const SizedBox(height: 6),
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
            const SizedBox(height: KSpacing.md),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Save production mode'),
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: KSpacing.md),
                child: Text(_msg!,
                    style: TextStyle(color: _msgColor,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}
