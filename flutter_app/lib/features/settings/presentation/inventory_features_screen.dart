import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/feature_flag_repository.dart';

class InventoryFeaturesScreen extends ConsumerStatefulWidget {
  const InventoryFeaturesScreen({super.key});

  @override
  ConsumerState<InventoryFeaturesScreen> createState() =>
      _InventoryFeaturesScreenState();
}

class _InventoryFeaturesScreenState
    extends ConsumerState<InventoryFeaturesScreen> {
  static const _featureLabels = {
    'MRP_PRICING': 'MRP Pricing',
    'BATCH_TRACKING': 'Batch Tracking',
    'EXPIRY_TRACKING': 'Expiry Date Tracking',
    'DRUG_SCHEDULE_FIELDS': 'Drug Schedule Fields',
    'WEIGHT_BASED_BILLING': 'Weight-Based Billing',
    'SIZE_COLOR_VARIANTS': 'Size & Colour Variants',
    'SERIAL_TRACKING': 'Serial Number Tracking',
    'MULTI_WAREHOUSE': 'Multi-Warehouse',
    'BARCODE_SCANNING': 'Barcode Scanning',
    'COMPOSITE_ITEMS': 'Composite / Bundle Items',
    'PRICE_TIERS': 'Price Tiers',
  };

  static const _featureDescriptions = {
    'MRP_PRICING': 'Set maximum retail price for items',
    'BATCH_TRACKING': 'Track inventory by batch numbers',
    'EXPIRY_TRACKING': 'Monitor product expiry dates',
    'DRUG_SCHEDULE_FIELDS': 'Drug schedule, dosage & composition',
    'WEIGHT_BASED_BILLING': 'Bill by weight (kg, gm, etc.)',
    'SIZE_COLOR_VARIANTS': 'Item variants by size and colour',
    'SERIAL_TRACKING': 'Track items by unique serial numbers',
    'MULTI_WAREHOUSE': 'Manage multiple warehouse locations',
    'BARCODE_SCANNING': 'Scan barcodes while creating items',
    'COMPOSITE_ITEMS': 'Bundle multiple items into one',
    'PRICE_TIERS': 'Customer-group-based pricing',
  };

  bool _resetting = false;
  final Map<String, bool> _pendingToggles = {};

  Future<void> _toggle(String feature, bool newValue) async {
    setState(() => _pendingToggles[feature] = true);
    try {
      await ref
          .read(featureFlagRepositoryProvider)
          .toggleFeature(feature, enabled: newValue);
      ref.invalidate(featureFlagsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update $feature')),
        );
      }
    } finally {
      if (mounted) setState(() => _pendingToggles.remove(feature));
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
            'This will re-enable the features recommended for your industry and disable others. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _resetting = true);
    try {
      await ref.read(featureFlagRepositoryProvider).resetToDefaults();
      ref.invalidate(featureFlagsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flagsAsync = ref.watch(featureFlagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Features'),
        actions: [
          if (_resetting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _resetToDefaults,
              child: const Text('Reset'),
            ),
        ],
      ),
      body: flagsAsync.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorView(
          message: 'Failed to load features',
          onRetry: () => ref.invalidate(featureFlagsProvider),
        ),
        data: (enabledSet) {
          final features = _featureLabels.keys.toList();
          return ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: features.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final feature = features[i];
              final isEnabled = enabledSet.contains(feature);
              final isToggling = _pendingToggles.containsKey(feature);
              return SwitchListTile.adaptive(
                value: isEnabled,
                onChanged: isToggling
                    ? null
                    : (v) => _toggle(feature, v),
                title: Text(
                  _featureLabels[feature] ?? feature,
                  style: KTypography.bodyMedium,
                ),
                subtitle: Text(
                  _featureDescriptions[feature] ?? '',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
                activeColor: KColors.primary,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                secondary: isToggling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
