import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/feature_flag_repository.dart';
import 'auth_state.dart';

class BusinessCapabilities {
  final bool canUseAccounting;
  final bool canUseAiInbox;
  final bool canUsePos;
  final bool canUseInventory;
  final bool canUseDistribution;
  final bool canUsePharma;
  final bool canUseManufacturing;
  final bool canUseBatchExpiry;
  final bool canUseBankRecon;
  final bool canUseReports;

  const BusinessCapabilities({
    required this.canUseAccounting,
    required this.canUseAiInbox,
    required this.canUsePos,
    required this.canUseInventory,
    required this.canUseDistribution,
    required this.canUsePharma,
    required this.canUseManufacturing,
    required this.canUseBatchExpiry,
    required this.canUseBankRecon,
    required this.canUseReports,
  });

  static const none = BusinessCapabilities(
    canUseAccounting: false,
    canUseAiInbox: false,
    canUsePos: false,
    canUseInventory: false,
    canUseDistribution: false,
    canUsePharma: false,
    canUseManufacturing: false,
    canUseBatchExpiry: false,
    canUseBankRecon: false,
    canUseReports: false,
  );

  static const allEnabled = BusinessCapabilities(
    canUseAccounting: true,
    canUseAiInbox: true,
    canUsePos: true,
    canUseInventory: true,
    canUseDistribution: true,
    canUsePharma: true,
    canUseManufacturing: true,
    canUseBatchExpiry: true,
    canUseBankRecon: true,
    canUseReports: true,
  );

  factory BusinessCapabilities.fromEnabledFeatures(Set<String> features) {
    bool has(String key) => features.contains(key);
    return BusinessCapabilities(
      canUseAccounting: has('ACCOUNTING'),
      canUseAiInbox: has('AI_INBOX'),
      canUsePos: has('POS'),
      canUseInventory: has('INVENTORY'),
      canUseDistribution: has('DISTRIBUTION'),
      canUsePharma: has('PHARMA'),
      canUseManufacturing: has('MANUFACTURING'),
      canUseBatchExpiry: has('BATCH_EXPIRY'),
      canUseBankRecon: has('BANK_RECON'),
      canUseReports: has('REPORTS'),
    );
  }

  factory BusinessCapabilities.fallback(AuthState auth) {
    final type = auth.businessType?.toUpperCase();
    final code = auth.industryCode?.toUpperCase() ?? auth.industry?.toUpperCase();
    final isRetail = type == 'RETAILER';
    final isDistributor = type == 'DISTRIBUTOR';
    final isManufacturer = type == 'MANUFACTURER';
    final isPharma = code == 'PHARMACY' || code?.contains('PHARMA') == true;

    return BusinessCapabilities(
      canUseAccounting: true,
      canUseAiInbox: true,
      canUsePos: isRetail,
      canUseInventory: isRetail || isDistributor || isManufacturer || isPharma,
      canUseDistribution: isDistributor,
      canUsePharma: isPharma,
      canUseManufacturing: isManufacturer,
      canUseBatchExpiry: isPharma,
      canUseBankRecon: true,
      canUseReports: true,
    );
  }
}

const bool _previewAllModules =
    bool.fromEnvironment('PREVIEW_ALL_MODULES', defaultValue: false);

final previewAllModulesProvider = Provider<bool>((ref) {
  if (!kDebugMode) return false;
  return _previewAllModules;
});

final businessCapabilitiesProvider = Provider<BusinessCapabilities>((ref) {
  final auth = ref.watch(authProvider);
  final previewAllModules = ref.watch(previewAllModulesProvider);
  final enabledFeatures = ref.watch(featureFlagsProvider).valueOrNull;
  if (!auth.isAuthenticated) {
    return BusinessCapabilities.none;
  }
  if (previewAllModules) {
    return BusinessCapabilities.allEnabled;
  }
  if (enabledFeatures == null || enabledFeatures.isEmpty) {
    return BusinessCapabilities.fallback(auth);
  }
  return BusinessCapabilities.fromEnabledFeatures(enabledFeatures);
});
