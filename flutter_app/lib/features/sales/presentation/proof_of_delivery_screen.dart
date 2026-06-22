import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Proof of Delivery — back-office capture for delivered shipments.
/// Lets staff record the recipient + delivery time + GPS for a delivery
/// challan or invoice and attach signature / photo files. Files reuse the
/// shared AttachmentService (entityType=POD) on the server.
class ProofOfDeliveryScreen extends ConsumerStatefulWidget {
  const ProofOfDeliveryScreen({super.key});

  @override
  ConsumerState<ProofOfDeliveryScreen> createState() =>
      _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends ConsumerState<ProofOfDeliveryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? const [];

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(apiClientProvider).get(ApiConfig.proofOfDelivery);
      if (!mounted) return;
      setState(() => _rows = _list(res.data['data']));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Delivery'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _recordNew,
        icon: const Icon(Icons.add),
        label: const Text('Record POD'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No PODs recorded yet.\n\nTap "Record POD" after a '
                      'delivery to log who received it and attach the '
                      'signature or photo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _podCard(_rows[i]),
                  ),
                ),
    );
  }

  Widget _podCard(Map<String, dynamic> pod) {
    final link = pod['deliveryChallanId'] != null
        ? 'DC ${_short(pod['deliveryChallanId'])}'
        : pod['invoiceId'] != null
            ? 'Invoice ${_short(pod['invoiceId'])}'
            : '(unlinked)';
    final delivered = pod['deliveredAt']?.toString().replaceAll('T', ' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pod['recipientName']?.toString() ?? '(unknown)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(link,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (pod['recipientRelation'] != null) '${pod['recipientRelation']}',
                if (pod['recipientPhone'] != null) '${pod['recipientPhone']}',
                if (delivered != null) 'at $delivered',
              ].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (pod['notes'] != null && (pod['notes'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(pod['notes'] as String),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _attach(pod),
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('Attach file'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _viewAttachments(pod),
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Attachments'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(pod),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _short(Object? id) {
    final s = id?.toString() ?? '';
    return s.length > 8 ? s.substring(0, 8) : s;
  }

  Future<void> _recordNew() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _RecordPodDialog(),
    );
    if (result == null) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.proofOfDelivery,
          data: result);
      _toast('POD recorded');
      await _load();
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _attach(Map<String, dynamic> pod) async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.first.bytes == null) {
      return;
    }
    final f = picked.files.first;
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(f.bytes!.toList(), filename: f.name),
      });
      await ref.read(apiClientProvider).dio.post(
            ApiConfig.proofOfDeliveryAttachments(pod['id'] as String),
            data: form,
          );
      _toast('Attached');
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _viewAttachments(Map<String, dynamic> pod) async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .get(ApiConfig.proofOfDeliveryAttachments(pod['id'] as String));
      final atts = _list(res.data['data']);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Attachments for ${pod['recipientName']}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (atts.isEmpty)
                const Text('None yet — tap "Attach file" on the card.')
              else
                ...atts.map((a) => ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(a['fileName']?.toString() ?? '(file)'),
                      subtitle: Text(
                          '${a['fileType'] ?? ''} · ${a['fileSize'] ?? 0} bytes'),
                    )),
            ],
          ),
        ),
      );
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> pod) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(
            'Remove POD for ${pod['recipientName']}? '
            'Attached files stay on storage and can be cleaned later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .delete(ApiConfig.proofOfDeliveryById(pod['id'] as String));
      _toast('Removed');
      await _load();
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    }
  }
}

// ─────────────────── Dialog ───────────────────

class _RecordPodDialog extends StatefulWidget {
  const _RecordPodDialog();

  @override
  State<_RecordPodDialog> createState() => _RecordPodDialogState();
}

class _RecordPodDialogState extends State<_RecordPodDialog> {
  final _dcId = TextEditingController();
  final _invoiceId = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relation = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _notes = TextEditingController();
  DateTime _deliveredAt = DateTime.now();

  String _pad(int n) => n.toString().padLeft(2, '0');
  String _fmt(DateTime d) =>
      '${d.year}-${_pad(d.month)}-${_pad(d.day)} ${_pad(d.hour)}:${_pad(d.minute)}';

  Future<void> _pickDeliveredAt() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deliveredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deliveredAt),
    );
    if (t == null) return;
    setState(() {
      _deliveredAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _name.text.trim().isNotEmpty &&
            (_dcId.text.trim().isNotEmpty || _invoiceId.text.trim().isNotEmpty);
    return AlertDialog(
      title: const Text('Record proof of delivery'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Link this POD to either a delivery challan or an invoice. '
                'Paste the id from the corresponding screen.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dcId,
                decoration: const InputDecoration(
                  labelText: 'Delivery challan id',
                ),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _invoiceId,
                decoration: const InputDecoration(labelText: 'Invoice id'),
                onChanged: (_) => setState(() {}),
              ),
              const Divider(height: 24),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Recipient name *'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Recipient phone'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: _relation,
                decoration: const InputDecoration(
                    labelText: 'Relationship (Self / Watchman / …)'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDeliveredAt,
                      icon: const Icon(Icons.access_time),
                      label: Text('Delivered: ${_fmt(_deliveredAt)}'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lat,
                      decoration: const InputDecoration(labelText: 'GPS lat'),
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lng,
                      decoration: const InputDecoration(labelText: 'GPS lng'),
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: !ready
              ? null
              : () => Navigator.pop(context, {
                    if (_dcId.text.trim().isNotEmpty)
                      'deliveryChallanId': _dcId.text.trim(),
                    if (_invoiceId.text.trim().isNotEmpty)
                      'invoiceId': _invoiceId.text.trim(),
                    'recipientName': _name.text.trim(),
                    if (_phone.text.trim().isNotEmpty)
                      'recipientPhone': _phone.text.trim(),
                    if (_relation.text.trim().isNotEmpty)
                      'recipientRelation': _relation.text.trim(),
                    'deliveredAt': _deliveredAt.toUtc().toIso8601String(),
                    if (_lat.text.trim().isNotEmpty)
                      'geoLatitude': double.tryParse(_lat.text.trim()),
                    if (_lng.text.trim().isNotEmpty)
                      'geoLongitude': double.tryParse(_lng.text.trim()),
                    if (_notes.text.trim().isNotEmpty)
                      'notes': _notes.text.trim(),
                  }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
