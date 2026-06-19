import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/routing_repository.dart';

/// Manage work instructions / SOPs / drawings attached to a manufacturing
/// operation (tracker #13). Operators on the shop floor can later open
/// these files from a job card — the upload UI for the engineering team
/// lives here.
///
/// Intentionally simple: paste an operation id (or get here via a list
/// item that already knows it), see the attachment list, upload more,
/// delete stale ones.
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
        SnackBar(content: Text('Uploaded ${f.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${ApiErrorParser.message(e)}')),
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
        const SnackBar(content: Text('Attachment deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${ApiErrorParser.message(e)}')),
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
                      labelText: 'Operation id',
                      helperText:
                          'Paste the id of the operation whose SOPs you want to manage',
                      prefixIcon: Icon(Icons.engineering_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                FilledButton(onPressed: _load, child: const Text('Open')),
              ],
            ),
          ),
          Expanded(
            child: _operationId == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text('Enter an operation id to view its attachments'),
                      ],
                    ),
                  )
                : _AttachmentsView(operationId: _operationId!, onDelete: _delete),
          ),
        ],
      ),
      floatingActionButton: _operationId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _upload,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload'),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: Text('No attachments yet — upload an SOP, drawing or video'),
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final a = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: ListTile(
                leading: const Icon(Icons.attach_file),
                title: Text(a['fileName']?.toString() ?? 'Attachment ${i + 1}'),
                subtitle: Text(
                  '${a['contentType'] ?? 'unknown'} • ${a['fileSize'] ?? 0} bytes',
                  style: KTypography.bodySmall,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => onDelete(a['id'].toString()),
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
