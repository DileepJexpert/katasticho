import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/onboarding/data/organisation_repository.dart';
import '../../features/settings/data/feature_flag_repository.dart';
import 'auth_state.dart';
import 'module_overrides.dart';

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
  final bool canUseFieldSales;
  final bool canUsePartnerNetwork;
  final bool canUsePayroll;
  final bool canUseSupplyChain;
  final bool canUseCourier;

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
    required this.canUseFieldSales,
    required this.canUsePartnerNetwork,
    required this.canUsePayroll,
    required this.canUseSupplyChain,
    required this.canUseCourier,
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
    canUseFieldSales: false,
    canUsePartnerNetwork: false,
    canUsePayroll: false,
    canUseSupplyChain: false,
    canUseCourier: false,
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
    canUseFieldSales: true,
    canUsePartnerNetwork: true,
    canUsePayroll: true,
    canUseSupplyChain: true,
    canUseCourier: true,
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
      canUseFieldSales: has('FIELD_SALES'),
      canUsePartnerNetwork: has('PARTNER_NETWORK'),
      canUsePayroll: has('PAYROLL'),
      canUseSupplyChain: has('SUPPLY_CHAIN'),
      canUseCourier: has('COURIER') || has('TRANSPORT'),
    );
  }

  factory BusinessCapabilities.fromEnabledFeaturesAndProfile(
    Set<String> features,
    AuthState auth,
  ) {
    final fromFlags = BusinessCapabilities.fromEnabledFeatures(features);
    final fromProfile = BusinessCapabilities.fallback(auth);
    return BusinessCapabilities(
      canUseAccounting:
          fromFlags.canUseAccounting || fromProfile.canUseAccounting,
      canUseAiInbox: fromFlags.canUseAiInbox || fromProfile.canUseAiInbox,
      canUsePos: fromFlags.canUsePos || fromProfile.canUsePos,
      canUseInventory: fromFlags.canUseInventory || fromProfile.canUseInventory,
      canUseDistribution:
          fromFlags.canUseDistribution || fromProfile.canUseDistribution,
      canUsePharma: fromFlags.canUsePharma || fromProfile.canUsePharma,
      canUseManufacturing:
          fromFlags.canUseManufacturing || fromProfile.canUseManufacturing,
      canUseBatchExpiry:
          fromFlags.canUseBatchExpiry || fromProfile.canUseBatchExpiry,
      canUseBankRecon: fromFlags.canUseBankRecon || fromProfile.canUseBankRecon,
      canUseReports: fromFlags.canUseReports || fromProfile.canUseReports,
      canUseFieldSales:
          fromFlags.canUseFieldSales || fromProfile.canUseFieldSales,
      canUsePartnerNetwork:
          fromFlags.canUsePartnerNetwork || fromProfile.canUsePartnerNetwork,
      canUsePayroll: fromFlags.canUsePayroll || fromProfile.canUsePayroll,
      canUseSupplyChain:
          fromFlags.canUseSupplyChain || fromProfile.canUseSupplyChain,
      canUseCourier: fromFlags.canUseCourier || fromProfile.canUseCourier,
    );
  }

  factory BusinessCapabilities.fallback(AuthState auth) {
    final type = _normalized(auth.businessType);
    final code = _normalized(auth.industryCode ?? auth.industry);
    final isRetail = type.contains('RETAIL') || code.contains('RETAIL');
    final isDistributor =
        type.contains('DISTRIBUTOR') || code.contains('DISTRIBUTOR');
    final isManufacturer =
        type.contains('MANUFACTURER') || code.contains('MANUFACTURER');
    final isPharma = code == 'PHARMACY' || code.contains('PHARMA');

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
      canUseFieldSales: isDistributor,
      canUsePartnerNetwork: isDistributor,
      // Vertical-appropriate defaults. A plain retailer does not see HR &
      // Payroll / Supply Planning / Courier by default (they were leaking
      // before because these routes had no capability gate); a distributor or
      // manufacturer does. Any org can still turn a module on via its feature
      // flags (which OR-in above), which is what the QA test account relies on.
      canUsePayroll: isDistributor || isManufacturer,
      canUseSupplyChain: isDistributor || isManufacturer,
      canUseCourier: isDistributor,
    );
  }

  /// Apply per-org authoritative module-visibility overrides on top of the
  /// computed capabilities. A module present in [overrides] uses that explicit
  /// value (an admin's Show/Hide decision wins); a module absent keeps its
  /// computed default. This is what lets an org tweak the vertical default in
  /// both directions without affecting any other org.
  BusinessCapabilities applyModuleOverrides(Map<String, bool> overrides) {
    if (overrides.isEmpty) return this;
    bool eff(String code, bool base) =>
        overrides.containsKey(code) ? overrides[code]! : base;
    return BusinessCapabilities(
      canUseAccounting: eff('ACCOUNTING', canUseAccounting),
      canUseAiInbox: eff('AI_INBOX', canUseAiInbox),
      canUsePos: eff('POS', canUsePos),
      canUseInventory: eff('INVENTORY', canUseInventory),
      canUseDistribution: eff('DISTRIBUTION', canUseDistribution),
      canUsePharma: eff('PHARMA', canUsePharma),
      canUseManufacturing: eff('MANUFACTURING', canUseManufacturing),
      canUseBatchExpiry: eff('BATCH_EXPIRY', canUseBatchExpiry),
      canUseBankRecon: eff('BANK_RECON', canUseBankRecon),
      canUseReports: eff('REPORTS', canUseReports),
      canUseFieldSales: eff('FIELD_SALES', canUseFieldSales),
      canUsePartnerNetwork: eff('PARTNER_NETWORK', canUsePartnerNetwork),
      canUsePayroll: eff('PAYROLL', canUsePayroll),
      canUseSupplyChain: eff('SUPPLY_CHAIN', canUseSupplyChain),
      canUseCourier: eff('COURIER', canUseCourier),
    );
  }

  static String _normalized(String? value) =>
      (value ?? '').trim().toUpperCase();
}

const bool _previewAllModules =
    bool.fromEnvironment('PREVIEW_ALL_MODULES', defaultValue: false);

const _previewAllModulesStorageKey = 'dev_preview_all_modules';

class PreviewAllModulesNotifier extends StateNotifier<bool> {
  PreviewAllModulesNotifier() : super(kDebugMode && _previewAllModules) {
    _restore();
  }

  Future<void> _restore() async {
    if (!kDebugMode) {
      state = false;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_previewAllModulesStorageKey);
    if (stored != null) {
      state = stored;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (!kDebugMode) return;
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_previewAllModulesStorageKey, enabled);
  }

  Future<void> resetToDefault() async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_previewAllModulesStorageKey);
    state = _previewAllModules;
  }
}

final previewAllModulesProvider =
    StateNotifierProvider<PreviewAllModulesNotifier, bool>((ref) {
  return PreviewAllModulesNotifier();
});

final businessCapabilitiesProvider =
    Provider.autoDispose<BusinessCapabilities>((ref) {
  final auth = ref.watch(authProvider);
  final previewAllModules = ref.watch(previewAllModulesProvider);
  final enabledFeatures = ref.watch(featureFlagsProvider).valueOrNull;
  final orgDetails = ref.watch(orgDetailsProvider).valueOrNull;
  final profileAuth = auth.copyWith(
    businessType: orgDetails?['businessType'] as String?,
    industryCode: orgDetails?['industryCode'] as String?,
    industry: orgDetails?['industry'] as String?,
  );
  if (!auth.isAuthenticated) {
    return BusinessCapabilities.none;
  }
  if (previewAllModules) {
    return BusinessCapabilities.allEnabled;
  }
  final overrides =
      ref.watch(moduleOverridesProvider).valueOrNull ?? const <String, bool>{};
  final base = (enabledFeatures == null || enabledFeatures.isEmpty)
      ? BusinessCapabilities.fallback(profileAuth)
      : BusinessCapabilities.fromEnabledFeaturesAndProfile(
          enabledFeatures,
          profileAuth,
        );
  // Per-org admin Show/Hide decisions win over the computed default.
  return base.applyModuleOverrides(overrides);
});
