import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/currency_repository.dart';

final _currenciesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(currencyRepositoryProvider).listCurrencies();
});

final _exchangeRatesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(currencyRepositoryProvider).getExchangeRates();
});

class CurrencyScreen extends ConsumerStatefulWidget {
  const CurrencyScreen({super.key});

  @override
  ConsumerState<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends ConsumerState<CurrencyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currencies'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Currencies'),
            Tab(text: 'Exchange Rates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CurrenciesTab(),
          _ExchangeRatesTab(),
        ],
      ),
    );
  }
}

class _CurrenciesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currenciesAsync = ref.watch(_currenciesProvider);

    return currenciesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (currencies) {
        if (currencies.isEmpty) {
          return const Center(child: Text('No currencies configured'));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_currenciesProvider),
          child: ListView.builder(
            padding: KSpacing.screenPadding,
            itemCount: currencies.length,
            itemBuilder: (_, i) {
              final c = currencies[i] as Map<String, dynamic>;
              final isBase = c['isBase'] as bool? ?? false;
              return Card(
                margin: const EdgeInsets.only(bottom: KSpacing.sm),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isBase
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      (c['symbol'] as String? ?? '?'),
                      style: TextStyle(
                        color: isBase
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(c['code'] as String? ?? '', style: KTypography.titleSmall),
                      const SizedBox(width: KSpacing.sm),
                      if (isBase)
                        const Chip(
                          label: Text('Base', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  subtitle: Text(c['name'] as String? ?? ''),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ExchangeRatesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(_exchangeRatesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Set Exchange Rate',
        onPressed: () => _showSetRateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ratesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
        data: (rates) {
          if (rates.isEmpty) {
            return const Center(child: Text('No exchange rates configured'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_exchangeRatesProvider),
            child: ListView.builder(
              padding: KSpacing.screenPadding,
              itemCount: rates.length,
              itemBuilder: (_, i) {
                final r = rates[i] as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: ListTile(
                    leading: const Icon(Icons.currency_exchange_outlined),
                    title: Text(
                      '${r['fromCurrency']} → ${r['toCurrency']}',
                      style: KTypography.titleSmall,
                    ),
                    subtitle: Text('Updated: ${r['updatedAt'] ?? 'N/A'}'),
                    trailing: Text(
                      r['rate']?.toString() ?? '—',
                      style: KTypography.titleMedium.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onTap: () => _showSetRateDialog(context, ref, existing: r),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSetRateDialog(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    final fromCtrl =
        TextEditingController(text: existing?['fromCurrency'] as String? ?? '');
    final toCtrl =
        TextEditingController(text: existing?['toCurrency'] as String? ?? '');
    final rateCtrl =
        TextEditingController(text: existing?['rate']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Set Exchange Rate' : 'Update Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromCtrl,
              decoration: const InputDecoration(
                  labelText: 'From Currency (e.g. USD)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: KSpacing.sm),
            TextField(
              controller: toCtrl,
              decoration: const InputDecoration(
                  labelText: 'To Currency (e.g. INR)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: KSpacing.sm),
            TextField(
              controller: rateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Rate', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await ref.read(currencyRepositoryProvider).setExchangeRate(
                      fromCurrency: fromCtrl.text.trim().toUpperCase(),
                      toCurrency: toCtrl.text.trim().toUpperCase(),
                      rate: double.parse(rateCtrl.text.trim()),
                    );
                ref.invalidate(_exchangeRatesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                        content: Text(ApiErrorParser.message(e)),
                        backgroundColor: KColors.error),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
