import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HSN → GST rate master. The table is shared across all orgs (rates are
/// statutory facts): admins can ADD missing codes; editing an existing code
/// needs a platform admin, so the backend rejects those with a clear error.
class HsnMasterScreen extends ConsumerStatefulWidget {
  const HsnMasterScreen({super.key});

  @override
  ConsumerState<HsnMasterScreen> createState() => _HsnMasterScreenState();
}

class _HsnMasterScreenState extends ConsumerState<HsnMasterScreen> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final response = await ref.read(apiClientProvider).get(
        ApiConfig.hsnGstMasterSearch,
        queryParameters: {'q': q, 'limit': 50},
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() => _results =
            (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? []);
      }
    } catch (e) {
      _toast('Search failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addHsn() async {
    final codeCtl = TextEditingController();
    final descCtl = TextEditingController();
    final rateCtl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add HSN code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'HSN code', hintText: 'e.g. 1905'),
            ),
            TextField(
              controller: descCtl,
              decoration: const InputDecoration(
                  labelText: 'Description', hintText: 'e.g. Bread, biscuits'),
            ),
            TextField(
              controller: rateCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'GST rate %',
                  helperText: 'Verify against the CBIC rate schedule'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(apiClientProvider).post(
        ApiConfig.pharmacyHsnUpsert,
        data: {
          'hsnCode': codeCtl.text.trim(),
          'description': descCtl.text.trim(),
          'gstRate': double.tryParse(rateCtl.text) ?? 0,
        },
      );
      _toast('HSN saved');
      _search(_searchCtrl.text);
    } catch (e) {
      _toast('Save failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HSN / GST Rates')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHsn,
        icon: const Icon(Icons.add),
        label: const Text('Add HSN'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search HSN code or description',
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No HSN codes found'))
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final h = _results[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 22,
                          child: Text('${h['gstRate'] ?? 0}%',
                              style: const TextStyle(fontSize: 11)),
                        ),
                        title: Text('${h['hsnCode']} — ${h['description']}'),
                        subtitle: h['category'] != null
                            ? Text(h['category'].toString())
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
