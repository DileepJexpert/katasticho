import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../auth/auth_state.dart';
import '../utils/currency_formatter.dart';

/// The signed-in org's country settings, fetched from
/// `GET /api/v1/reference/country-profile`. Watching this provider after login
/// applies the org's currency to [CurrencyFormatter] as a side effect, so every
/// `KMoney` cell renders in the right currency (₹ for India, AED for UAE, OMR
/// for Oman at 3 decimals) without per-widget plumbing.
class CountryProfileInfo {
  final String countryCode;
  final String currencyCode;
  final String currencySymbol;
  final int currencyDecimals;
  final String taxIdLabel;

  const CountryProfileInfo({
    required this.countryCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.currencyDecimals,
    required this.taxIdLabel,
  });

  static const CountryProfileInfo india = CountryProfileInfo(
    countryCode: 'IN',
    currencyCode: 'INR',
    currencySymbol: '₹',
    currencyDecimals: 2,
    taxIdLabel: 'GSTIN',
  );

  factory CountryProfileInfo.fromJson(Map<String, dynamic> j) => CountryProfileInfo(
        countryCode: (j['countryCode'] as String?) ?? 'IN',
        currencyCode: (j['currencyCode'] as String?) ?? 'INR',
        currencySymbol: (j['currencySymbol'] as String?) ?? '₹',
        currencyDecimals: (j['currencyDecimals'] as int?) ?? 2,
        taxIdLabel: (j['taxIdLabel'] as String?) ?? 'GSTIN',
      );

  /// Apply this org's currency to the global formatter. India keeps ₹ + lakh/
  /// crore grouping; other countries use their code (e.g. "AED 1,050.00") with
  /// Western grouping and the country's decimal precision.
  void applyToFormatter() {
    if (countryCode == 'IN') {
      CurrencyFormatter.setActiveCurrency(
          symbol: '₹', decimals: 2, indianGrouping: true);
    } else {
      CurrencyFormatter.setActiveCurrency(
          symbol: '$currencyCode ',
          decimals: currencyDecimals,
          indianGrouping: false);
    }
  }
}

/// Fetches the country profile once per logged-in session and applies the
/// currency. Errors fall back to India (no money-display change).
final countryProfileProvider =
    FutureProvider<CountryProfileInfo>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.orgId == null || auth.orgId!.isEmpty) {
    return CountryProfileInfo.india;
  }
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get<Map<String, dynamic>>(ApiConfig.countryProfile);
    final data = res.data?['data'] as Map<String, dynamic>?;
    final info = data == null
        ? CountryProfileInfo.india
        : CountryProfileInfo.fromJson(data);
    info.applyToFormatter();
    return info;
  } catch (_) {
    CountryProfileInfo.india.applyToFormatter();
    return CountryProfileInfo.india;
  }
});
