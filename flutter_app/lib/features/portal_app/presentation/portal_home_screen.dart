import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_config.dart';
import '../data/portal_session.dart';

/// External portal landing screen. Loads the profile + dashboard, then shows a
/// customer or vendor experience depending on the portal user's kind.
class PortalHomeScreen extends ConsumerStatefulWidget {
  const PortalHomeScreen({super.key});

  @override
  ConsumerState<PortalHomeScreen> createState() => _PortalHomeScreenState();
}

class _PortalHomeScreenState extends ConsumerState<PortalHomeScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _dashboard;

  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(portalDioProvider);
      final results = await Future.wait([
        dio.get(ApiConfig.portalMe),
        dio.get(ApiConfig.portalDashboard),
      ]);
      if (!mounted) return;
      setState(() {
        _me = results[0].data['data'] as Map<String, dynamic>?;
        _dashboard = results[1].data['data'] as Map<String, dynamic>?;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your account.';
        _loading = false;
      });
    }
  }

  String _errorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to load your account. Please try again.';
  }

  void _logout() {
    ref.read(portalTokenProvider.notifier).state = null;
    ref.read(portalProfileProvider.notifier).state = null;
    context.go('/portal/login');
  }

  String _title() {
    final contact = _me?['contact'];
    if (contact is Map && contact['displayName'] is String) {
      return contact['displayName'] as String;
    }
    final name = _me?['fullName'];
    if (name is String && name.isNotEmpty) return name;
    return 'My Portal';
  }

  String _kind() {
    final fromMe = _me?['kind'];
    if (fromMe is String && fromMe.isNotEmpty) return fromMe;
    final fromDash = _dashboard?['kind'];
    if (fromDash is String) return fromDash;
    final profile = ref.read(portalProfileProvider);
    final fromProfile = profile?['kind'];
    return fromProfile is String ? fromProfile : 'CUSTOMER';
  }

  static String money(dynamic v) {
    final n = (v is num) ? v : num.tryParse('${v ?? 0}') ?? 0;
    return _money.format(n);
  }

  @override
  Widget build(BuildContext context) {
    final isVendor = _kind() == 'VENDOR';
    final tabCount = isVendor ? 3 : 3; // Summary + two detail tabs.

    return DefaultTabController(
      length: tabCount,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title()),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: _loading || _error != null
              ? null
              : TabBar(
                  isScrollable: true,
                  tabs: isVendor
                      ? const [
                          Tab(text: 'Overview'),
                          Tab(text: 'Purchase orders'),
                          Tab(text: 'Bills'),
                        ]
                      : const [
                          Tab(text: 'Overview'),
                          Tab(text: 'All invoices'),
                          Tab(text: 'Statement'),
                        ],
                ),
        ),
        body: _buildBody(isVendor),
      ),
    );
  }

  Widget _buildBody(bool isVendor) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (isVendor) {
      return TabBarView(
        children: [
          _VendorOverview(dashboard: _dashboard ?? const {}),
          _ListTab(
            fetch: () => ref.read(portalDioProvider).get(ApiConfig.portalPurchaseOrders),
            emptyText: 'No purchase orders yet.',
            builder: (row) => _docTile(row, amountKey: 'total'),
          ),
          _ListTab(
            fetch: () => ref.read(portalDioProvider).get(ApiConfig.portalBills),
            emptyText: 'No bills yet.',
            builder: (row) => _docTile(row, amountKey: 'balanceDue'),
          ),
        ],
      );
    }
    return TabBarView(
      children: [
        _CustomerOverview(dashboard: _dashboard ?? const {}),
        _ListTab(
          fetch: () => ref.read(portalDioProvider).get(ApiConfig.portalInvoices),
          emptyText: 'No invoices yet.',
          builder: (row) => _docTile(row, amountKey: 'balanceDue'),
        ),
        _StatementTab(
          fetch: () => ref.read(portalDioProvider).get(ApiConfig.portalStatement),
        ),
      ],
    );
  }

  Widget _docTile(Map<String, dynamic> row, {required String amountKey}) {
    final number = (row['number'] ?? row['id'] ?? '—').toString();
    final date = (row['date'] ?? '').toString();
    final status = (row['status'] ?? '').toString();
    return ListTile(
      title: Text(number),
      subtitle: Text([
        if (date.isNotEmpty) date,
        if (status.isNotEmpty) status,
      ].join('  •  ')),
      trailing: Text(
        money(row[amountKey]),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CustomerOverview extends StatelessWidget {
  const _CustomerOverview({required this.dashboard});

  final Map<String, dynamic> dashboard;

  @override
  Widget build(BuildContext context) {
    final recent = (dashboard['recentInvoices'] as List?) ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(
          headline: 'Outstanding',
          headlineValue: _PortalHomeScreenState.money(dashboard['outstanding']),
          chips: [
            _Stat('Open invoices', '${dashboard['openInvoiceCount'] ?? 0}'),
            _Stat('Total invoices', '${dashboard['totalInvoiceCount'] ?? 0}'),
          ],
        ),
        const SizedBox(height: 16),
        Text('Recent invoices',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const _EmptyHint('No recent invoices.')
        else
          ...recent.map((e) {
            final row = (e as Map).cast<String, dynamic>();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text((row['number'] ?? '—').toString()),
                subtitle: Text([
                  (row['date'] ?? '').toString(),
                  (row['status'] ?? '').toString(),
                ].where((s) => s.isNotEmpty).join('  •  ')),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_PortalHomeScreenState.money(row['total']),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Due ${_PortalHomeScreenState.money(row['balanceDue'])}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _VendorOverview extends StatelessWidget {
  const _VendorOverview({required this.dashboard});

  final Map<String, dynamic> dashboard;

  @override
  Widget build(BuildContext context) {
    final recent = (dashboard['recentPurchaseOrders'] as List?) ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(
          headline: 'Payable to you',
          headlineValue:
              _PortalHomeScreenState.money(dashboard['payableToYou']),
          chips: [
            _Stat('Unpaid bills', '${dashboard['unpaidBillCount'] ?? 0}'),
            _Stat('Open POs', '${dashboard['openPurchaseOrderCount'] ?? 0}'),
          ],
        ),
        const SizedBox(height: 16),
        Text('Recent purchase orders',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (recent.isEmpty)
          const _EmptyHint('No recent purchase orders.')
        else
          ...recent.map((e) {
            final row = (e as Map).cast<String, dynamic>();
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text((row['number'] ?? '—').toString()),
                subtitle: Text([
                  (row['date'] ?? '').toString(),
                  (row['status'] ?? '').toString(),
                ].where((s) => s.isNotEmpty).join('  •  ')),
                trailing: Text(_PortalHomeScreenState.money(row['total']),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            );
          }),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.headline,
    required this.headlineValue,
    required this.chips,
  });

  final String headline;
  final String headlineValue;
  final List<_Stat> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(headline, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(headlineValue, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in chips)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.value, style: theme.textTheme.titleLarge),
                      Text(c.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final String value;
}

/// Generic GET-a-list-and-render tab.
class _ListTab extends StatefulWidget {
  const _ListTab({
    required this.fetch,
    required this.builder,
    required this.emptyText,
  });

  final Future<Response<dynamic>> Function() fetch;
  final Widget Function(Map<String, dynamic> row) builder;
  final String emptyText;

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.fetch();
      final data = res.data['data'];
      final list = (data is List ? data : const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'Unable to load.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return _EmptyHint(widget.emptyText);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => widget.builder(_rows[i]),
      ),
    );
  }
}

/// Statement tab: opening/closing summary + ledger entries.
class _StatementTab extends StatefulWidget {
  const _StatementTab({required this.fetch});

  final Future<Response<dynamic>> Function() fetch;

  @override
  State<_StatementTab> createState() => _StatementTabState();
}

class _StatementTabState extends State<_StatementTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.fetch();
      if (!mounted) return;
      setState(() {
        _data = res.data['data'] as Map<String, dynamic>?;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _error = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'Unable to load statement.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load statement.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }
    final data = _data ?? const {};
    final entries = (data['entries'] as List?) ?? const [];
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _row(context, 'Opening balance',
                      _PortalHomeScreenState.money(data['openingBalance'])),
                  _row(context, 'Total invoiced',
                      _PortalHomeScreenState.money(data['totalInvoiced'])),
                  _row(context, 'Total paid',
                      _PortalHomeScreenState.money(data['totalPaid'])),
                  const Divider(),
                  _row(
                    context,
                    'Closing balance',
                    _PortalHomeScreenState.money(data['closingBalance']),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Entries', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const _EmptyHint('No statement entries.')
          else
            ...entries.map((e) {
              final row = (e as Map).cast<String, dynamic>();
              final debit = row['debit'];
              final credit = row['credit'];
              final hasDebit = (debit is num ? debit : 0) != 0;
              final amount = hasDebit
                  ? '+${_PortalHomeScreenState.money(debit)}'
                  : '-${_PortalHomeScreenState.money(credit)}';
              return ListTile(
                dense: true,
                title: Text([
                  (row['type'] ?? '').toString(),
                  (row['number'] ?? '').toString(),
                ].where((s) => s.isNotEmpty).join('  '))
                ,
                subtitle: Text((row['date'] ?? '').toString()),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(amount),
                    Text(
                      _PortalHomeScreenState.money(row['runningBalance']),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
