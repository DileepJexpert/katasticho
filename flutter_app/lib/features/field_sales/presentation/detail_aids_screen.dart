import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// E-detailing management: URL-based brochures / visual aids the field
/// team presents during visits, with usage counts. Works for any vertical.
class DetailAidsScreen extends ConsumerStatefulWidget {
  const DetailAidsScreen({super.key});

  @override
  ConsumerState<DetailAidsScreen> createState() => _DetailAidsScreenState();
}

class _DetailAidsScreenState extends ConsumerState<DetailAidsScreen> {
  List<Map<String, dynamic>> _aids = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .get(ApiConfig.mrDetailAidsManage);
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() => _aids =
            (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? []);
      }
    } catch (e) {
      _toast('Failed to load detail aids: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final nameCtl = TextEditingController(text: existing?['name'] ?? '');
    final descCtl =
        TextEditingController(text: existing?['description'] ?? '');
    final urlCtl = TextEditingController(text: existing?['mediaUrl'] ?? '');
    final productCtl =
        TextEditingController(text: existing?['productName'] ?? '');
    String type = existing?['mediaType']?.toString() ?? 'PDF';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add detail aid' : 'Edit detail aid'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: urlCtl,
                  decoration: const InputDecoration(
                    labelText: 'Media URL',
                    helperText: 'https:// link to the hosted PDF/image/video',
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                    DropdownMenuItem(value: 'IMAGE', child: Text('Image')),
                    DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                    DropdownMenuItem(value: 'LINK', child: Text('Web link')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'LINK'),
                ),
                TextField(
                  controller: productCtl,
                  decoration: const InputDecoration(
                      labelText: 'Product (optional)'),
                ),
                TextField(
                  controller: descCtl,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                ),
              ],
            ),
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
      ),
    );
    if (ok != true) return;

    final body = {
      'name': nameCtl.text.trim(),
      'mediaUrl': urlCtl.text.trim(),
      'mediaType': type,
      if (descCtl.text.trim().isNotEmpty) 'description': descCtl.text.trim(),
      if (productCtl.text.trim().isNotEmpty)
        'productName': productCtl.text.trim(),
    };
    try {
      final api = ref.read(apiClientProvider);
      if (existing == null) {
        await api.post(ApiConfig.mrDetailAids, data: body);
      } else {
        await api.put(ApiConfig.mrDetailAidById(existing['id'].toString()),
            data: {...body, 'active': existing['active']});
      }
      await _load();
    } catch (e) {
      _toast('Save failed: $e');
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> aid) async {
    try {
      await ref.read(apiClientProvider).put(
        ApiConfig.mrDetailAidById(aid['id'].toString()),
        data: {
          'name': aid['name'],
          'mediaUrl': aid['mediaUrl'],
          'mediaType': aid['mediaType'],
          'description': aid['description'],
          'productName': aid['productName'],
          'active': !(aid['active'] == true),
        },
      );
      await _load();
    } catch (e) {
      _toast('Update failed: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> aid) async {
    try {
      await ref
          .read(apiClientProvider)
          .delete(ApiConfig.mrDetailAidById(aid['id'].toString()));
      await _load();
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  IconData _typeIcon(String? type) => switch (type) {
        'PDF' => Icons.picture_as_pdf_outlined,
        'IMAGE' => Icons.image_outlined,
        'VIDEO' => Icons.play_circle_outline,
        _ => Icons.link,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Aids (E-detailing)'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Aid'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _aids.isEmpty
              ? const Center(
                  child: Text('No detail aids yet.\nAdd brochures or visual '
                      'aids your field team shows to customers.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _aids.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final aid = _aids[i];
                    final active = aid['active'] == true;
                    return ListTile(
                      leading: Icon(_typeIcon(aid['mediaType']?.toString()),
                          color: active ? null : Colors.grey),
                      title: Text(aid['name']?.toString() ?? '',
                          style: active
                              ? null
                              : const TextStyle(color: Colors.grey)),
                      subtitle: Text(
                        [
                          aid['productName'],
                          'shown ${aid['timesShown'] ?? 0}×',
                        ]
                            .where((x) =>
                                x != null && x.toString().trim().isNotEmpty)
                            .join(' • '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_new, size: 20),
                            tooltip: 'Open media',
                            onPressed: () => launchUrl(
                                Uri.parse(aid['mediaUrl'].toString()),
                                mode: LaunchMode.externalApplication),
                          ),
                          Switch(
                            value: active,
                            onChanged: (_) => _toggleActive(aid),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _edit(aid),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _delete(aid),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
