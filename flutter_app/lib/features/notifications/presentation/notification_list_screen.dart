import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/notification_repository.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncNotifications = ref.watch(notificationListProvider(0));

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
                      .markAllAsRead();
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
                                .markAsRead(id);
                            ref.invalidate(notificationListProvider);
                            ref.invalidate(unreadCountProvider);
                          }
                          // Navigate to the related entity if possible
                          if (context.mounted) {
                            _navigateToEntity(context, n);
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

  void _navigateToEntity(BuildContext context, Map<String, dynamic> n) {
    final entityType = n['entityType'] as String?;
    final entityId = n['entityId'] as String?;
    if (entityType == null || entityId == null) return;

    final route = switch (entityType.toUpperCase()) {
      'INVOICE' => '/invoices/$entityId',
      'BILL' => '/bills/$entityId',
      'ESTIMATE' => '/estimates/$entityId',
      'CONTACT' => '/contacts/$entityId',
      'ITEM' => '/items/$entityId',
      'EXPENSE' => '/expenses/$entityId',
      'CREDIT_NOTE' => '/credit-notes/$entityId',
      'SALES_ORDER' => '/sales-orders/$entityId',
      'VENDOR_PAYMENT' => '/vendor-payments/$entityId',
      'VENDOR_CREDIT' => '/vendor-credits/$entityId',
      'STOCK_RECEIPT' => '/stock-receipts/$entityId',
      'DELIVERY_CHALLAN' => '/delivery-challans/$entityId',
      'RECURRING_INVOICE' => '/recurring-invoices/$entityId',
      _ => null,
    };

    if (route != null) {
      context.push(route);
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final severity = notification['severity'] as String? ?? 'INFO';
    final type = notification['type'] as String? ?? '';
    final isRead = notification['read'] as bool? ?? false;
    final createdAt = notification['createdAt'] as String?;
    final metadata = notification['metadata'] as Map<String, dynamic>?;
    final whatsappLink = metadata?['whatsappLink'] as String?;

    final dotColor = _dotColor(severity, type);

    final icon = switch (severity) {
      'CRITICAL' => Icons.error_outline_rounded,
      'WARNING' => Icons.warning_amber_rounded,
      _ => Icons.info_outline_rounded,
    };

    return Material(
      color: isRead
          ? Colors.transparent
          : dotColor.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md, vertical: KSpacing.sm + 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colored dot + icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: dotColor),
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
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(message, style: KTypography.bodySmall),
                    KSpacing.vGapXs,
                    Row(
                      children: [
                        if (createdAt != null)
                          Expanded(
                            child: Text(
                              _formatRelativeTime(createdAt),
                              style: KTypography.labelSmall,
                            ),
                          ),
                        if (whatsappLink != null && whatsappLink.isNotEmpty)
                          _WhatsAppButton(link: whatsappLink),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the dot color based on severity and notification type.
  ///
  /// Red: CRITICAL severity, PAYMENT_REMINDER, EXPIRY_ALERT
  /// Yellow/amber: WARNING severity, LOW_STOCK_ALERT, BILL_OVERDUE
  /// Green: INFO severity, DAILY_SUMMARY
  Color _dotColor(String severity, String type) {
    // Type-based overrides first
    switch (type.toUpperCase()) {
      case 'PAYMENT_REMINDER':
      case 'EXPIRY_ALERT':
        return KColors.error;
      case 'LOW_STOCK_ALERT':
      case 'BILL_OVERDUE':
        return KColors.warning;
      case 'DAILY_SUMMARY':
        return KColors.success;
    }
    // Fall back to severity
    return switch (severity.toUpperCase()) {
      'CRITICAL' => KColors.error,
      'WARNING' => KColors.warning,
      _ => KColors.success,
    };
  }

  String _formatRelativeTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.isNegative) return 'Just now';
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) {
        final m = diff.inMinutes;
        return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
      }
      if (diff.inHours < 24) {
        final h = diff.inHours;
        return '$h ${h == 1 ? 'hour' : 'hours'} ago';
      }
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) {
        final w = diff.inDays ~/ 7;
        return '$w ${w == 1 ? 'week' : 'weeks'} ago';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _WhatsAppButton extends StatelessWidget {
  final String link;

  const _WhatsAppButton({required this.link});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextButton.icon(
        onPressed: () async {
          final uri = Uri.parse(link);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          foregroundColor: const Color(0xFF25D366),
        ),
        icon: const Icon(Icons.chat_rounded, size: 14),
        label: Text('WhatsApp', style: KTypography.labelSmall),
      ),
    );
  }
}
