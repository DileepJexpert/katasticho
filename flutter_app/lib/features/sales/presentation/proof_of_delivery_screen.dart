import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

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
              ? KEmptyState(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'No proof of delivery recorded yet',
                  subtitle:
                      'Tap "Record POD" after a delivery to log who received it and attach signatures or photos.',
                  actionLabel: 'Record POD',
                  onAction: _recordNew,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
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

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pod['recipientName']?.toString() ?? '(unknown)',
                  style: KTypography.titleMedium,
                ),
              ),
              KStatusChip(
                status: 'DELIVERED',
                label: link,
              ),
            ],
          ),
          KSpacing.vGapXs,
          Text(
            [
              if (pod['recipientRelation'] != null)
                '${pod['recipientRelation']}',
              if (pod['recipientPhone'] != null) '${pod['recipientPhone']}',
              if (delivered != null) 'at $delivered',
            ].join(' · '),
            style: KTypography.bodySmall,
          ),
          if (pod['notes'] != null && (pod['notes'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: KSpacing.xs),
              child: Text(pod['notes'] as String, style: KTypography.bodyMedium),
            ),
          KSpacing.vGapSm,
          Row(
            children: [
              KButton(
                label: 'Attach File',
                icon: Icons.attach_file,
                size: KButtonSize.small,
                variant: KButtonVariant.outlined,
                onPressed: () => _attach(pod),
              ),
              KSpacing.hGapSm,
              KButton(
                label: 'Attachments',
                icon: Icons.folder_open,
                size: KButtonSize.small,
                variant: KButtonVariant.outlined,
                onPressed: () => _viewAttachments(pod),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline, color: KColors.error, size: 20),
                onPressed: () => _delete(pod),
              ),
            ],
          ),
        ],
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
      _toast('POD recorded successfully');
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
      _toast('File attached successfully');
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
            padding: KSpacing.pagePadding,
            children: [
              Text('Attachments for ${pod['recipientName']}',
                  style: KTypography.titleMedium),
              KSpacing.vGapMd,
              if (atts.isEmpty)
                const Text('No attachments yet — tap "Attach File" on the card.')
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
        title: const Text('Remove Proof of Delivery'),
        content: Text(
            'Remove POD for ${pod['recipientName']}? '
            'Attached files stay on storage and can be cleaned later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
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

  @override
  void dispose() {
    _dcId.dispose();
    _invoiceId.dispose();
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    _lat.dispose();
    _lng.dispose();
    _notes.dispose();
    super.dispose();
  }

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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Record Proof of Delivery', style: KTypography.h3),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  'Link this POD to either a delivery challan or an invoice. Paste the ID below.',
                  style: KTypography.bodySmall,
                ),
                KSpacing.vGapMd,

                // Document Linking
                KCompactRow(
                  children: [
                    KTextField(
                      label: 'Delivery Challan ID',
                      hint: 'e.g. dc_123',
                      controller: _dcId,
                      onChanged: (_) => setState(() {}),
                    ),
                    KTextField(
                      label: 'Invoice ID',
                      hint: 'e.g. inv_123',
                      controller: _invoiceId,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                KSpacing.vGapSm,

                // Recipient Info
                KCompactRow(
                  children: [
                    KTextField(
                      label: 'Recipient Name *',
                      hint: 'Full name',
                      controller: _name,
                      onChanged: (_) => setState(() {}),
                    ),
                    KTextField(
                      label: 'Recipient Phone',
                      hint: '10-digit phone',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                KSpacing.vGapSm,

                KCompactRow(
                  children: [
                    KTextField(
                      label: 'Relationship',
                      hint: 'e.g. Self, Watchman, Manager',
                      controller: _relation,
                    ),
                    InkWell(
                      onTap: _pickDeliveredAt,
                      borderRadius: KSpacing.borderRadiusMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivered At', style: KTypography.labelLarge),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                              borderRadius: KSpacing.borderRadiusMd,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, size: 18, color: Theme.of(context).colorScheme.primary),
                                KSpacing.hGapXs,
                                Text(_fmt(_deliveredAt), style: KTypography.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapSm,

                // GPS
                KCompactRow(
                  children: [
                    KTextField(
                      label: 'GPS Latitude',
                      hint: 'e.g. 19.0760',
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                    ),
                    KTextField(
                      label: 'GPS Longitude',
                      hint: 'e.g. 72.8777',
                      controller: _lng,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapSm,

                KTextField(
                  label: 'Notes',
                  hint: 'Special remarks, condition of package, etc.',
                  controller: _notes,
                  maxLines: 2,
                ),
                KSpacing.vGapLg,

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    KButton(
                      label: 'Cancel',
                      variant: KButtonVariant.outlined,
                      onPressed: () => Navigator.pop(context),
                    ),
                    KSpacing.hGapSm,
                    KButton(
                      label: 'Save POD',
                      icon: Icons.check,
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
