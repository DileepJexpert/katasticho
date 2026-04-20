import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/onboarding_state.dart';
import '../data/organisation_repository.dart';

const _indianStates = [
  {'code': '01', 'name': 'Jammu & Kashmir'},
  {'code': '02', 'name': 'Himachal Pradesh'},
  {'code': '03', 'name': 'Punjab'},
  {'code': '04', 'name': 'Chandigarh'},
  {'code': '05', 'name': 'Uttarakhand'},
  {'code': '06', 'name': 'Haryana'},
  {'code': '07', 'name': 'Delhi'},
  {'code': '08', 'name': 'Rajasthan'},
  {'code': '09', 'name': 'Uttar Pradesh'},
  {'code': '10', 'name': 'Bihar'},
  {'code': '11', 'name': 'Sikkim'},
  {'code': '12', 'name': 'Arunachal Pradesh'},
  {'code': '13', 'name': 'Nagaland'},
  {'code': '14', 'name': 'Manipur'},
  {'code': '15', 'name': 'Mizoram'},
  {'code': '16', 'name': 'Tripura'},
  {'code': '17', 'name': 'Meghalaya'},
  {'code': '18', 'name': 'Assam'},
  {'code': '19', 'name': 'West Bengal'},
  {'code': '20', 'name': 'Jharkhand'},
  {'code': '21', 'name': 'Odisha'},
  {'code': '22', 'name': 'Chhattisgarh'},
  {'code': '23', 'name': 'Madhya Pradesh'},
  {'code': '24', 'name': 'Gujarat'},
  {'code': '25', 'name': 'Daman & Diu'},
  {'code': '26', 'name': 'Dadra & Nagar Haveli'},
  {'code': '27', 'name': 'Maharashtra'},
  {'code': '29', 'name': 'Karnataka'},
  {'code': '30', 'name': 'Goa'},
  {'code': '31', 'name': 'Lakshadweep'},
  {'code': '32', 'name': 'Kerala'},
  {'code': '33', 'name': 'Tamil Nadu'},
  {'code': '34', 'name': 'Puducherry'},
  {'code': '35', 'name': 'Andaman & Nicobar'},
  {'code': '36', 'name': 'Telangana'},
  {'code': '37', 'name': 'Andhra Pradesh'},
  {'code': '38', 'name': 'Ladakh'},
];

class BusinessDetailsScreen extends ConsumerStatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  ConsumerState<BusinessDetailsScreen> createState() =>
      _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends ConsumerState<BusinessDetailsScreen> {
  final _gstinController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedStateCode;
  bool _saving = false;
  String? _error;

  String get _selectedStateName {
    if (_selectedStateCode == null) return '';
    final match = _indianStates
        .where((s) => s['code'] == _selectedStateCode)
        .firstOrNull;
    return match?['name'] ?? '';
  }

  @override
  void dispose() {
    _gstinController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _skipAndSaveIndustry() async {
    setState(() => _saving = true);
    try {
      final onboarding = ref.read(onboardingProvider);
      final orgId = ref.read(authProvider).orgId;
      if (orgId != null) {
        await ref.read(organisationRepositoryProvider).updateIndustry(
              orgId: orgId,
              businessType: onboarding.businessType,
              industryCode: onboarding.industryCode,
              subCategories: onboarding.subCategories,
            );
      }
    } catch (_) {
      // proceed to complete regardless
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        context.go(Routes.onboardingComplete);
      }
    }
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final onboarding = ref.read(onboardingProvider);
      final orgId = ref.read(authProvider).orgId;
      if (orgId == null) throw Exception('No org ID in session');

      ref.read(onboardingProvider.notifier).setDetails(
            gstin: _gstinController.text.trim(),
            stateName: _selectedStateName,
            stateCode: _selectedStateCode ?? '',
            phone: _phoneController.text.trim(),
          );

      await ref.read(organisationRepositoryProvider).updateIndustry(
            orgId: orgId,
            businessType: onboarding.businessType,
            industryCode: onboarding.industryCode,
            subCategories: onboarding.subCategories,
            gstin: _gstinController.text.trim(),
            state: _selectedStateName,
            stateCode: _selectedStateCode ?? '',
            phone: _phoneController.text.trim(),
          );

      if (mounted) context.go(Routes.onboardingComplete);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.textPrimary),
          onPressed: () => context.go(Routes.onboardingSubCategory),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business details', style: KTypography.h1),
              KSpacing.vGapSm,
              Text(
                'Optional — you can update these later in Settings.',
                style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
              ),
              KSpacing.vGapXl,
              if (_error != null) ...[
                KErrorBanner(
                  message: _error!,
                  onDismiss: () => setState(() => _error = null),
                ),
                KSpacing.vGapMd,
              ],
              KTextField(
                label: 'GSTIN',
                controller: _gstinController,
                hint: 'e.g. 27AABCU9603R1ZX',
                prefixIcon: Icons.receipt_long_outlined,
              ),
              KSpacing.vGapMd,
              DropdownButtonFormField<String>(
                value: _selectedStateCode,
                decoration: InputDecoration(
                  labelText: 'State',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: KSpacing.borderRadiusMd,
                  ),
                ),
                items: _indianStates.map((s) {
                  return DropdownMenuItem(
                    value: s['code'],
                    child: Text('${s['name']} (${s['code']})'),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedStateCode = v),
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'Business Phone',
                controller: _phoneController,
                hint: 'e.g. 9876543210',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              KSpacing.vGapXl,
              KButton(
                label: 'Save & Continue',
                fullWidth: true,
                size: KButtonSize.large,
                isLoading: _saving,
                onPressed: _submit,
              ),
              KSpacing.vGapSm,
              TextButton(
                onPressed: _saving ? null : _skipAndSaveIndustry,
                child: Center(
                  child: Text(
                    'Skip for now',
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                ),
              ),
              KSpacing.vGapMd,
            ],
          ),
        ),
      ),
    );
  }
}
