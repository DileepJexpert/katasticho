import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/notification_repository.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifications = ref.watch(notificationListProvider);

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Notifications',
            actions: [
              TextButton(
                onPressed: () async {
                  await ref
                      .read(notificationRepositoryProvider)
                      .markAllRead();
                  ref.invalidate(notificationListProvider);
                  ref.invalidate(unreadCountProvider);
                },
                child: const Text('Mark all read'),
              ),
            ],
          ),
          Expanded(
            child: asyncNotifications.when(
              loading: () => const KShimmerList(),
              error: (_, __) => KErrorView(
                message: 'Failed to load notifications',
                onRetry: () => ref.invalidate(notificationListProvider),
              ),
              data: (data) {
                final content = data['data'];
                final notifications = content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []);

                if (notifications.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'All caught up!',
                    subtitle: 'No new notifications',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(notificationListProvider);
                    ref.invalidate(unreadCountProvider);
                  },
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 60),
                    itemBuilder: (context, i) {
                      final n = notifications[i] as Map<String, dynamic>;
                      return _NotificationTile(
                        notification: n,
                        onTap: () async {
                          final id = n['id']?.toString();
                          if (id != null && n['read'] != true) {
                            await ref
                                .read(notificationRepositoryProvider)
                                .markRead(id);
                            ref.invalidate(notificationListProvider);
                            ref.invalidate(unreadCountProvider);
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile(
      {required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final severity = notification['severity'] as String? ?? 'INFO';
    final isRead = notification['read'] as bool? ?? false;
    final createdAt = notification['createdAt'] as String?;

    final iconColor = switch (severity) {
      'CRITICAL' => KColors.error,
      'WARNING' => KColors.warning,
      _ => KColors.info,
    };

    final icon = switch (severity) {
      'CRITICAL' => Icons.error_outline_rounded,
      'WARNING' => Icons.warning_amber_rounded,
      _ => Icons.info_outline_rounded,
    };

    return Material(
      color: isRead
          ? Colors.transparent
          : iconColor.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md, vertical: KSpacing.sm + 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: iconColor),
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
                            title,
                            style: KTypography.labelLarge.copyWith(
                              fontWeight: isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: iconColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(message, style: KTypography.bodySmall),
                    if (createdAt != null) ...[
                      KSpacing.vGapXs,
                      Text(
                        _formatDate(createdAt),
                        style: KTypography.labelSmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
