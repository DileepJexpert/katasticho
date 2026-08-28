import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/field_sales_repository.dart';

/// Admin view of where every field salesperson is right now.
/// Auto-refreshes every 30 seconds from the location ping trail.
class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _locations = [];
  Timer? _refreshTimer;
  DateTime? _lastRefreshed;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final locations =
          await ref.read(fieldSalesRepositoryProvider).getLiveLocations();
      if (mounted) {
        setState(() {
          _locations = locations;
          _lastRefreshed = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load live locations: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _openInMaps(Map<String, dynamic> loc) async {
    final lat = loc['latitude'];
    final lng = loc['longitude'];
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showTrail(Map<String, dynamic> loc) async {
    final executionId = loc['routeExecutionId']?.toString();
    if (executionId == null || executionId.isEmpty) return;
    try {
      final trail = await ref
          .read(fieldSalesRepositoryProvider)
          .getLocationTrail(executionId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (context) => _TrailSheet(
          salespersonName: loc['salespersonName']?.toString() ?? '',
          trail: trail,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load trail: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  String _relativeTime(String? iso) {
    if (iso == null) return '—';
    final time = DateTime.tryParse(iso)?.toLocal();
    if (time == null) return '—';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
    return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isStale(String? iso) {
    final time = iso != null ? DateTime.tryParse(iso) : null;
    if (time == null) return true;
    return DateTime.now().toUtc().difference(time.toUtc()).inMinutes > 15;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Field Tracking'),
        actions: [
          if (_lastRefreshed != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Updated ${_relativeTime(_lastRefreshed!.toIso8601String())}',
                  style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: KLoading())
          : _locations.isEmpty
              ? const KEmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'No location pings received today',
                  subtitle: 'Salespeople appear here once their field app starts sending GPS pings during an active route run.',
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: _locations.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final loc = _locations[index];
                      final stale = _isStale(loc['recordedAt']?.toString());
                      final name =
                          loc['salespersonName']?.toString().trim() ?? '';
                      final hasExecution = loc['routeExecutionId'] != null;
                      final lat = loc['latitude'];
                      final lng = loc['longitude'];

                      return KCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: stale
                                  ? KColors.warning.withValues(alpha: 0.15)
                                  : KColors.success.withValues(alpha: 0.15),
                              child: Icon(
                                stale ? Icons.location_searching : Icons.my_location,
                                color: stale ? KColors.warning : KColors.success,
                                size: 20,
                              ),
                            ),
                            KSpacing.hGapMd,
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name.isEmpty ? 'Salesperson' : name,
                                        style: KTypography.titleMedium,
                                      ),
                                      KSpacing.hGapSm,
                                      if (stale)
                                        const KStatusChip(
                                          status: 'WARNING',
                                          label: 'Stale',
                                        )
                                      else
                                        const KStatusChip(
                                          status: 'ACTIVE',
                                          label: 'Live',
                                        ),
                                    ],
                                  ),
                                  KSpacing.vGapXxs,
                                  Row(
                                    children: [
                                      Text(
                                        '$lat, $lng',
                                        style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '  •  ${_relativeTime(loc['recordedAt']?.toString())}',
                                        style: KTypography.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasExecution)
                                  IconButton(
                                    icon: const Icon(Icons.timeline, color: KColors.primary),
                                    tooltip: 'View trail',
                                    onPressed: () => _showTrail(loc),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.map_outlined),
                                  tooltip: 'Open in Maps',
                                  onPressed: () => _openInMaps(loc),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _TrailSheet extends StatelessWidget {
  const _TrailSheet({
    required this.salespersonName,
    required this.trail,
  });

  final String salespersonName;
  final Map<String, dynamic> trail;

  @override
  Widget build(BuildContext context) {
    final pings = (trail['pings'] as List?) ?? [];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              salespersonName.isEmpty
                  ? "Today's Trail"
                  : "$salespersonName — Today's Trail",
              style: KTypography.titleLarge,
            ),
            KSpacing.vGapMd,
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Distance travelled',
                    value: '${trail['totalDistanceKm'] ?? 0} km',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'GPS pings',
                    value: '${trail['pingCount'] ?? pings.length}',
                  ),
                ),
              ],
            ),
            KSpacing.vGapMd,
            if (pings.isNotEmpty) ...[
              KCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flight_takeoff, size: 14, color: KColors.primary),
                            KSpacing.hGapXs,
                            Text('First ping: ', style: KTypography.caption),
                            Text(
                              pings.first['recordedAt']?.toString().substring(11, 19) ?? '',
                              style: KTypography.mono(fontSize: 12),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.flight_land, size: 14, color: KColors.success),
                            KSpacing.hGapXs,
                            Text('Last ping: ', style: KTypography.caption),
                            Text(
                              pings.last['recordedAt']?.toString().substring(11, 19) ?? '',
                              style: KTypography.mono(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              KSpacing.vGapMd,
              Text('GPS Breadcrumb Waypoints', style: KTypography.h4),
              KSpacing.vGapXs,
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: pings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: KColors.divider),
                  itemBuilder: (ctx, i) {
                    final p = pings[i];
                    final lat = p['latitude'];
                    final lng = p['longitude'];
                    final acc = p['accuracyM'];
                    final time = p['recordedAt']?.toString() ?? '';
                    final timeStr = time.length > 19 ? time.substring(11, 19) : time;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: KColors.primary.withValues(alpha: 0.1),
                        child: Text('${i + 1}', style: const TextStyle(fontSize: 10, color: KColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text('$lat, $lng', style: KTypography.mono(fontSize: 12)),
                      subtitle: Text('Time: $timeStr • Accuracy: ${acc ?? "-"}m', style: KTypography.caption),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16, color: KColors.primary),
                        tooltip: 'Open in Maps',
                        onPressed: () async {
                          final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: KTypography.mono(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        KSpacing.vGapXxs,
        Text(label, style: KTypography.bodySmall),
      ],
    );
  }
}
