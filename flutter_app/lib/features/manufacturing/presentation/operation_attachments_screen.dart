import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/routing_repository.dart';

/// Manage work instructions / SOPs / drawings attached to a manufacturing
/// operation (tracker #13). Operators on the shop floor can later open
/// these files from a job card — the upload UI for the engineering team
/// lives here.
class OperationAttachmentsScreen extends ConsumerStatefulWidget {
  final String? initialOperationId;
  const OperationAttachmentsScreen({super.key, this.initialOperationId});

  @override
  ConsumerState<OperationAttachmentsScreen> createState() =>
      _OperationAttachmentsScreenState();
}

class _OperationAttachmentsScreenState
    extends ConsumerState<OperationAttachmentsScreen> {
  final _opCtl = TextEditingController();
  String? _operationId;

  @override
  void initState() {
    super.initState();
    if (widget.initialOperationId != null) {
      _opCtl.text = widget.initialOperationId!;
      _operationId = widget.initialOperationId;
    }
  }

  @override
  void dispose() {
    _opCtl.dispose();
    super.dispose();
  }

  void _load() {
    final id = _opCtl.text.trim();
    if (id.isEmpty) return;
    setState(() => _operationId = id);
  }

  Future<void> _upload() async {
    final opId = _operationId;
    if (opId == null) return;
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    if (f.bytes == null) return;
    try {
      await ref.read(routingRepositoryProvider).uploadOperationAttachment(
            opId,
            f.bytes!.toList(),
            f.name,
          );
      if (!mounted) return;
      ref.invalidate(_attachmentsProvider(opId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded ${f.name}'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
      );
    }
  }

  Future<void> _delete(String attachmentId) async {
    final opId = _operationId;
    if (opId == null) return;
    try {
      await ref
          .read(routingRepositoryProvider)
          .deleteOperationAttachment(attachmentId);
      if (!mounted) return;
      ref.invalidate(_attachmentsProvider(opId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment deleted'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operation Work Instructions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _opCtl,
                    decoration: const InputDecoration(
                      labelText: 'Operation ID',
                      helperText:
                          'Paste the ID of the operation whose SOPs you want to manage',
                      prefixIcon: Icon(Icons.engineering_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                KSpacing.hGapSm,
                KButton.primary(onPressed: _load, label: 'Open'),
              ],
            ),
          ),
          Expanded(
            child: _operationId == null
                ? const Center(
                    child: KEmptyState(
                      icon: Icons.description_outlined,
                      title: 'Select Operation',
                      subtitle: 'Enter an operation ID above to view and manage its attachments and SOPs.',
                    ),
                  )
                : _AttachmentsView(operationId: _operationId!, onDelete: _delete),
          ),
        ],
      ),
      floatingActionButton: _operationId == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: _upload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Document'),
            ),
    );
  }
}

class _AttachmentsView extends ConsumerWidget {
  final String operationId;
  final void Function(String attachmentId) onDelete;
  const _AttachmentsView({required this.operationId, required this.onDelete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_attachmentsProvider(operationId));
    return async.when(
      loading: () => const Center(child: KLoading(message: 'Loading attachments...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const KEmptyState(
            icon: Icons.attach_file,
            title: 'No attachments yet',
            subtitle: 'Upload an SOP, technical drawing, or work instruction document.',
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final a = rows[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                child: ListTile(
                  leading: const Icon(Icons.attach_file, color: KColors.primary),
                  title: Text(
                    a['fileName']?.toString() ?? 'Attachment ${i + 1}',
                    style: KTypography.labelLarge,
                  ),
                  subtitle: Text(
                    '${a['contentType'] ?? 'unknown'} • ${a['fileSize'] ?? 0} bytes',
                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: KColors.error),
                    onPressed: () => onDelete(a['id'].toString()),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

final _attachmentsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, operationId) {
  return ref
      .watch(routingRepositoryProvider)
      .listOperationAttachments(operationId);
});
