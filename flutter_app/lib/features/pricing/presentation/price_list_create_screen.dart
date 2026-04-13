import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/price_list_repository.dart';

/// Form for creating a new price list. The server flips the previous
/// default off inside the same transaction when `isDefault=true`, so
/// the user can toggle the default freely without extra client work.
class PriceListCreateScreen extends ConsumerStatefulWidget {
  const PriceListCreateScreen({super.key});

  @override
  ConsumerState<PriceListCreateScreen> createState() =>
      _PriceListCreateScreenState();
}

class _PriceListCreateScreenState
    extends ConsumerState<PriceListCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _currency = 'INR';
  bool _isDefault = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(priceListRepositoryProvider);
      final created = await repo.createPriceList({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'currency': _currency,
        'isDefault': _isDefault,
      });
      ref.invalidate(priceListsProvider);
      if (!mounted) return;
      final id = created['id']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Price list "${created['name']}" created')),
      );
      if (id != null) {
        context.go('/price-lists/$id');
      } else {
        context.go('/price-lists');
      }
    } catch (e, st) {
      debugPrint('[PriceListCreate] save FAILED: $e\n$st');
      setState(() {
        _errorMessage = 'Failed to create price list. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Price List')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: KSpacing.borderRadiusMd,
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Text(_errorMessage!,
                      style: KTypography.bodySmall
                          .copyWith(color: Colors.red.shade700)),
                ),
                KSpacing.vGapMd,
              ],
              KTextField(
                label: 'Name',
                controller: _nameController,
                prefixIcon: Icons.sell_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name required' : null,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'Description (optional)',
                controller: _descriptionController,
                prefixIcon: Icons.description_outlined,
                maxLines: 2,
              ),
              KSpacing.vGapMd,
              DropdownButtonFormField<String>(
                value: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: const [
                  DropdownMenuItem(value: 'INR', child: Text('INR — Indian Rupee')),
                  DropdownMenuItem(value: 'USD', child: Text('USD — US Dollar')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR — Euro')),
                  DropdownMenuItem(value: 'KES', child: Text('KES — Kenyan Shilling')),
                  DropdownMenuItem(value: 'NGN', child: Text('NGN — Nigerian Naira')),
                  DropdownMenuItem(value: 'GBP', child: Text('GBP — British Pound')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'INR'),
              ),
              KSpacing.vGapMd,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default price list'),
                subtitle: Text(
                  'Used when a customer has no pinned list. Flips the '
                  'current default off automatically.',
                  style: KTypography.bodySmall,
                ),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              KSpacing.vGapLg,
              KButton(
                label: 'Create Price List',
                fullWidth: true,
                isLoading: _saving,
                icon: Icons.check,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
