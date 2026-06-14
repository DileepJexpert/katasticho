import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR Employee Document management — Core HR module 7 UI.
/// Tabs: My Documents (upload + list + delete), Expiring (HR watchlist).
class EmployeeDocumentsScreen extends ConsumerStatefulWidget {
  const EmployeeDocumentsScreen({super.key});

  @override
  ConsumerState<EmployeeDocumentsScreen> createState() =>
      _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState
    extends ConsumerState<EmployeeDocumentsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _expiring = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final mine = await api.get(ApiConfig.hrDocumentsMine);
      List<Map<String, dynamic>> exp = [];
      try {
        final e = await api.get(ApiConfig.hrDocumentsExpiring,
            queryParameters: {'days': 30});
        exp = _list(e.data['data']);
      } catch (_) {
        // expiring view is HR-only; ignore if forbidden
      }
      if (!mounted) return;
      setState(() {
        _mine = _list(mine.data['data']);
        _expiring = exp;
      });
    } catch (e) {
      _toast('Failed to load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _upload() async {
    final title = TextEditingController();
    String category = 'ID_PROOF';
    DateTime? expiry;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Upload document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'ID_PROOF', child: Text('ID Proof')),
                    DropdownMenuItem(value: 'PAN', child: Text('PAN')),
                    DropdownMenuItem(value: 'INSURANCE', child: Text('Insurance')),
                    DropdownMenuItem(value: 'CONTRACT', child: Text('Contract')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (v) => setD(() => category = v ?? 'OTHER'),
                ),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expiry == null
                      ? 'Expiry: none'
                      : 'Expiry: ${expiry!.toIso8601String().split('T').first}'),
                  trailing: const Icon(Icons.event),
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: expiry ?? now,
                      firstDate: now,
                      lastDate: DateTime(now.year + 30),
                    );
                    if (d != null) setD(() => expiry = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Pick file & upload')),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;

    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty || picked.files.first.bytes == null) {
      return;
    }
    final f = picked.files.first;
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(f.bytes!.toList(), filename: f.name),
        'title': title.text.trim(),
        'category': category,
        if (expiry != null) 'expiry': expiry!.toIso8601String().split('T').first,
      });
      await ref.read(apiClientProvider).dio.post(ApiConfig.hrDocumentsMine, data: form);
      _toast('Uploaded');
      await _load();
    } catch (e) {
      _toast('Upload failed: $e');
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(apiClientProvider).delete(ApiConfig.hrDocumentById(id));
      await _load();
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Documents'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          bottom: const TabBar(tabs: [
            Tab(text: 'My Documents'),
            Tab(text: 'Expiring'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _upload,
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_mineTab(), _expiringTab()]),
      ),
    );
  }

  Widget _mineTab() {
    if (_mine.isEmpty) {
      return const Center(child: Text('No documents uploaded yet.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final d in _mine)
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(d['title']?.toString() ?? ''),
                subtitle: Text('${d['category']}'
                    '${d['expiryDate'] != null ? '  •  expires ${d['expiryDate']}' : ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(d['id'].toString()),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _expiringTab() {
    if (_expiring.isEmpty) {
      return const Center(child: Text('No documents expiring soon (HR view).'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final d in _expiring)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_busy, color: Colors.orange),
              title: Text(d['title']?.toString() ?? ''),
              subtitle: Text('${d['category']}  •  expires ${d['expiryDate']}'),
            ),
          ),
      ],
    );
  }
}
