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
import '../data/transport_repository.dart';

/// Proof of delivery — record who received a consignment + attach a signature or
/// photo (stored via AttachmentService). Linked to a delivery challan by id.
class ProofOfDeliveryScreen extends ConsumerStatefulWidget {
  const ProofOfDeliveryScreen({super.key});

  @override
  ConsumerState<ProofOfDeliveryScreen> createState() =>
      _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends ConsumerState<ProofOfDeliveryScreen> {
  List<dynamic>? _items;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(transportRepositoryProvider).listPod();
      if (mounted) setState(() { _items = r; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Load failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CreatePodSheet(),
    );
    if (created == true) await _load();
  }

  Future<void> _attach(String podId) async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty || picked.files.first.bytes == null) {
      return;
    }
    final f = picked.files.first;
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(f.bytes!.toList(), filename: f.name),
      });
      await ref
          .read(apiClientProvider)
          .dio
          .post(ApiConfig.podAttachments(podId), data: form);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidence attached')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attach failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Delivery'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Record POD'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  ...(_items ?? const []).map(_podCard),
                  if ((_items ?? const []).isEmpty)
                    KCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No proof-of-delivery records yet.',
                          textAlign: TextAlign.center,
                          style: KTypography.bodyMedium
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _podCard(dynamic p) {
    final atts = (p['attachments'] as List?) ?? const [];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: KColors.success, size: 20),
                KSpacing.hGapSm,
                Expanded(
                  child: Text(p['recipientName']?.toString() ?? 'Recipient',
                      style: KTypography.titleSmall),
                ),
                Text('${atts.length} file(s)',
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary)),
              ],
            ),
            KSpacing.vGapXs,
            Text(
              'Delivered ${(p['deliveredAt'] ?? '').toString().split('T').first}'
              '${p['recipientPhone'] != null ? ' · ${p['recipientPhone']}' : ''}',
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
            if (p['notes'] != null && (p['notes'] as String).isNotEmpty) ...[
              KSpacing.vGapXs,
              Text(p['notes'].toString(), style: KTypography.bodySmall),
            ],
            KSpacing.vGapSm,
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _attach(p['id'].toString()),
                icon: const Icon(Icons.add_a_photo, size: 16),
                label: const Text('Add signature / photo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePodSheet extends ConsumerStatefulWidget {
  const _CreatePodSheet();

  @override
  ConsumerState<_CreatePodSheet> createState() => _CreatePodSheetState();
}

class _CreatePodSheetState extends ConsumerState<_CreatePodSheet> {
  final _challan = TextEditingController();
  final _recipient = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_challan, _recipient, _phone, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_challan.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the delivery challan id this POD is for')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(transportRepositoryProvider).createPod({
        'deliveryChallanId': _challan.text.trim(),
        'recipientName': _recipient.text.trim(),
        'recipientPhone': _phone.text.trim(),
        'notes': _notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: ${e.toString().replaceAll('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record proof of delivery', style: KTypography.h3),
            KSpacing.vGapMd,
            KTextField(label: 'Delivery challan id', controller: _challan),
            KSpacing.vGapSm,
            KTextField(label: 'Recipient name', controller: _recipient),
            KSpacing.vGapSm,
            KTextField(label: 'Recipient phone', controller: _phone),
            KSpacing.vGapSm,
            KTextField(label: 'Notes', controller: _notes, maxLines: 2),
            KSpacing.vGapLg,
            KButton(
              label: _saving ? 'Saving…' : 'Save — then attach a photo',
              icon: Icons.save,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
