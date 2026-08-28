import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';

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
      _toast('Failed to load detail aids: $e', isError: true);
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
          title: Text(existing == null ? 'Add Visual Detail Aid' : 'Edit Detail Aid'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KTextField(
                    controller: nameCtl,
                    label: 'Aid Name *',
                    hint: 'e.g. Cardia-Plus Doctor Presentation 2026',
                    isRequired: true,
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: urlCtl,
                    label: 'Media URL (PDF / Video / Web) *',
                    hint: 'https://cdn.example.com/aids/presentation.pdf',
                    isRequired: true,
                  ),
                  KSpacing.vGapSm,
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Media Format Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PDF', child: Text('PDF Document')),
                      DropdownMenuItem(value: 'IMAGE', child: Text('Image Asset')),
                      DropdownMenuItem(value: 'VIDEO', child: Text('Video Presentation')),
                      DropdownMenuItem(value: 'LINK', child: Text('Web / Interactive Link')),
                    ],
                    onChanged: (v) => setDialogState(() => type = v ?? 'LINK'),
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: productCtl,
                    label: 'Associated Product / Molecule (Optional)',
                    hint: 'e.g. Atorvastatin 20mg',
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: descCtl,
                    label: 'Clinical Highlights / Description',
                    hint: 'Key talking points or study highlights',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            KButton.outlined(
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx, false),
              label: 'Cancel',
            ),
            KSpacing.hGapSm,
            KButton.primary(
              size: KButtonSize.small,
              label: 'Save Aid',
              onPressed: () {
                if (nameCtl.text.trim().isEmpty || urlCtl.text.trim().isEmpty) {
                  _toast('Name and Media URL are required', isError: true);
                  return;
                }
                Navigator.pop(ctx, true);
              },
            ),
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
      _toast(existing == null ? 'Detail aid created' : 'Detail aid updated');
      await _load();
    } catch (e) {
      _toast('Save failed: $e', isError: true);
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
      _toast('Update failed: $e', isError: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> aid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Detail Aid'),
        content: Text('Are you sure you want to delete "${aid['name']}"?'),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.danger(
            size: KButtonSize.small,
            label: 'Delete',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(apiClientProvider)
          .delete(ApiConfig.mrDetailAidById(aid['id'].toString()));
      _toast('Detail aid deleted');
      await _load();
    } catch (e) {
      _toast('Delete failed: $e', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? KColors.error : KColors.success,
      ),
    );
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
        title: const Text('E-Detailing & Digital Visual Aids'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New Visual Aid'),
      ),
      body: _loading
          ? const Center(child: KLoading())
          : _aids.isEmpty
              ? KEmptyState(
                  icon: Icons.tv_outlined,
                  title: 'No visual detail aids uploaded yet',
                  subtitle: 'Add digital brochures, PDFs, and clinical trial presentations for field representatives.',
                  actionLabel: 'New Visual Aid',
                  onAction: () => _edit(),
                )
              : ListView.separated(
                  padding: KSpacing.pagePadding,
                  itemCount: _aids.length,
                  separatorBuilder: (_, __) => KSpacing.vGapSm,
                  itemBuilder: (context, i) {
                    final aid = _aids[i];
                    final active = aid['active'] == true;
                    final mediaType = aid['mediaType']?.toString() ?? 'LINK';
                    final productName = aid['productName']?.toString();
                    final timesShown = (aid['timesShown'] as num?)?.toInt() ?? 0;

                    return KCard(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: active
                                  ? KColors.primary.withValues(alpha: 0.12)
                                  : KColors.divider.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _typeIcon(mediaType),
                              color: active ? KColors.primary : KColors.textHint,
                              size: 22,
                            ),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        aid['name']?.toString() ?? '',
                                        style: KTypography.titleMedium.copyWith(
                                          color: active ? null : KColors.textHint,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    KSpacing.hGapSm,
                                    KStatusChip(
                                      status: mediaType,
                                      label: mediaType,
                                    ),
                                    KSpacing.hGapXs,
                                    KStatusChip(
                                      status: active ? 'ACTIVE' : 'INACTIVE',
                                      label: active ? 'Active' : 'Disabled',
                                    ),
                                  ],
                                ),
                                KSpacing.vGapXxs,
                                Row(
                                  children: [
                                    if (productName != null && productName.isNotEmpty) ...[
                                      Text(productName, style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                                      const Text('  •  ', style: TextStyle(color: KColors.textSecondary)),
                                    ],
                                    Text('Presented: ', style: KTypography.bodySmall),
                                    Text('$timesShown×', style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          KSpacing.hGapSm,
                          IconButton(
                            icon: const Icon(Icons.open_in_new, size: 20, color: KColors.primary),
                            tooltip: 'Preview / Open media',
                            onPressed: () => launchUrl(
                              Uri.parse(aid['mediaUrl'].toString()),
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                          Switch(
                            value: active,
                            onChanged: (_) => _toggleActive(aid),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Edit',
                            onPressed: () => _edit(aid),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: KColors.error),
                            tooltip: 'Delete',
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
