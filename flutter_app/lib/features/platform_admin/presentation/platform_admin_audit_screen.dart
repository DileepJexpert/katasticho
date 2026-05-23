import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../data/platform_admin_repository.dart';

class PlatformAdminAuditScreen extends ConsumerStatefulWidget {
  const PlatformAdminAuditScreen({super.key});

  @override
  ConsumerState<PlatformAdminAuditScreen> createState() =>
      _PlatformAdminAuditScreenState();
}

class _PlatformAdminAuditScreenState
    extends ConsumerState<PlatformAdminAuditScreen> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _entries = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(platformAdminRepositoryProvider)
          .auditLog(page: _page, size: 20);
      final data = result['data'];
      final List<Map<String, dynamic>> items;
      if (data is List) {
        items = data.cast<Map<String, dynamic>>();
      } else if (data is Map<String, dynamic> && data['content'] is List) {
        items = (data['content'] as List).cast<Map<String, dynamic>>();
      } else {
        items = [];
      }

      setState(() {
        _entries.addAll(items);
        _page++;
        _hasMore = items.length >= 20;
      });
    } catch (_) {
      // Silently handle — user can scroll-retry
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _relativeTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 30) return '${diff.inDays}d ago';
      return dateStr.substring(0, 10);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log')),
      body: _entries.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Text(
                    'No audit log entries.',
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => KSpacing.vGapSm,
                  itemBuilder: (context, index) {
                    if (index >= _entries.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final entry = _entries[index];
                    final actionType =
                        entry['actionType']?.toString() ??
                            entry['action_type']?.toString() ??
                            '';
                    final targetName =
                        entry['targetName']?.toString() ??
                            entry['target_name']?.toString() ??
                            '';
                    final reason = entry['reason']?.toString() ?? '';
                    final performedAt =
                        entry['performedAt']?.toString() ??
                            entry['performed_at']?.toString() ??
                            '';
                    final ipAddress =
                        entry['ipAddress']?.toString() ??
                            entry['ip_address']?.toString() ??
                            '';

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
                                    actionType,
                                    style: KTypography.h4,
                                  ),
                                ),
                                Text(
                                  _relativeTime(performedAt),
                                  style: KTypography.labelSmall
                                      .copyWith(color: KColors.textHint),
                                ),
                              ],
                            ),
                            if (targetName.isNotEmpty)
                              Text(
                                targetName,
                                style: KTypography.bodyMedium,
                              ),
                            if (reason.isNotEmpty)
                              Text(
                                'Reason: $reason',
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.textSecondary),
                              ),
                            if (ipAddress.isNotEmpty)
                              Text(
                                ipAddress,
                                style: KTypography.labelSmall
                                    .copyWith(color: KColors.textHint),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
