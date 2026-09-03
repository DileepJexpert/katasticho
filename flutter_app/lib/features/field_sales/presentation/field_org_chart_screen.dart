import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Field reporting hierarchy: view the org chart (MR -> ABM -> RBM ...) as an
/// indented tree and assign each user's reporting manager. Works for all
/// verticals (FMCG / distribution / pharma).
class FieldOrgChartScreen extends ConsumerStatefulWidget {
  const FieldOrgChartScreen({super.key});

  @override
  ConsumerState<FieldOrgChartScreen> createState() =>
      _FieldOrgChartScreenState();
}

class _FieldOrgChartScreenState extends ConsumerState<FieldOrgChartScreen> {
  /// Flat list of org-chart nodes ({userId, fullName, role, reportsToUserId}).
  List<Map<String, dynamic>> _nodes = [];

  /// Org users for the manager picker.
  List<Map<String, dynamic>> _users = [];

  bool _loading = true;

  Dio get _dio => ref.read(apiClientProvider).dio;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final chartResp =
          await _dio.get<Map<String, dynamic>>(ApiConfig.fieldHierarchyOrgChart);
      final chartData = (chartResp.data?['data'] as List?) ?? [];

      final usersResp =
          await _dio.get<Map<String, dynamic>>(ApiConfig.orgUsers);
      final usersData = (usersResp.data?['data'] as List?) ?? [];

      if (!mounted) return;
      setState(() {
        _nodes = chartData
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _users = usersData
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      });
    } on DioException catch (e) {
      _toast('Failed to load org chart: ${_dioMessage(e)}', isError: true);
    } catch (e) {
      _toast('Failed to load org chart: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'request failed';
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

  String? _userId(Map<String, dynamic> n) => n['userId']?.toString();
  String? _managerId(Map<String, dynamic> n) =>
      n['reportsToUserId']?.toString();
  String _name(Map<String, dynamic> n) =>
      (n['fullName']?.toString().trim().isNotEmpty ?? false)
          ? n['fullName'].toString()
          : (n['role']?.toString() ?? 'User');

  /// Build a depth-annotated, ordered list from the flat node list.
  /// Roots = nodes with a null/missing manager, or whose manager is not in the
  /// set of known users (treat dangling manager as root). Children follow each
  /// parent. Guards against cycles via a visited set.
  List<_TreeRow> _buildTree() {
    final byId = <String, Map<String, dynamic>>{};
    for (final n in _nodes) {
      final id = _userId(n);
      if (id != null) byId[id] = n;
    }

    final childrenOf = <String, List<Map<String, dynamic>>>{};
    final roots = <Map<String, dynamic>>[];
    for (final n in _nodes) {
      final mgr = _managerId(n);
      if (mgr == null || mgr.isEmpty || !byId.containsKey(mgr)) {
        roots.add(n);
      } else {
        (childrenOf[mgr] ??= []).add(n);
      }
    }

    int byName(Map<String, dynamic> a, Map<String, dynamic> b) =>
        _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
    roots.sort(byName);
    for (final list in childrenOf.values) {
      list.sort(byName);
    }

    final rows = <_TreeRow>[];
    final visited = <String>{};

    void walk(Map<String, dynamic> n, int depth) {
      final id = _userId(n);
      if (id == null || !visited.add(id)) return; // cycle / missing id guard
      rows.add(_TreeRow(node: n, depth: depth));
      for (final c in childrenOf[id] ?? const []) {
        walk(c, depth + 1);
      }
    }

    for (final r in roots) {
      walk(r, 0);
    }
    return rows;
  }

  Future<void> _assignManager(Map<String, dynamic> node) async {
    final targetId = _userId(node);
    if (targetId == null) return;
    final currentMgr = _managerId(node);

    // Picker options: every org user except the node itself, plus a clear option.
    final options = _users.where((u) {
      final uid = (u['userId'] ?? u['id'])?.toString();
      return uid != null && uid != targetId;
    }).toList()
      ..sort((a, b) => '${a['fullName'] ?? a['email'] ?? ''}'
          .toLowerCase()
          .compareTo('${b['fullName'] ?? b['email'] ?? ''}'.toLowerCase()));

    final selected = await showDialog<_ManagerChoice>(
      context: context,
      builder: (ctx) {
        String? value = currentMgr;
        const noneSentinel = '__none__';
        return AlertDialog(
          title: Text('Reporting manager for ${_name(node)}'),
          content: SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                return DropdownButtonFormField<String>(
                  initialValue: value ?? noneSentinel,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Reports to', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                      value: noneSentinel,
                      child: Text('None (Top of hierarchy)'),
                    ),
                    ...options.map((u) {
                      final uid =
                          (u['userId'] ?? u['id'])?.toString() ?? '';
                      return DropdownMenuItem(
                        value: uid,
                        child: Text(
                          '${u['fullName'] ?? u['email'] ?? ''}'
                          '${u['role'] != null ? ' (${u['role']})' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (v) => setLocal(() => value = v),
                );
              },
            ),
          ),
          actions: [
            KButton.outlined(
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx),
              label: 'Cancel',
            ),
            KSpacing.hGapSm,
            KButton.primary(
              label: 'Save',
              size: KButtonSize.small,
              onPressed: () {
                final managerId =
                    (value == null || value == noneSentinel) ? null : value;
                Navigator.pop(ctx, _ManagerChoice(managerId));
              },
            ),
          ],
        );
      },
    );

    if (selected == null) return; // cancelled
    if (selected.managerId == currentMgr) return; // no change

    try {
      await _dio.put<Map<String, dynamic>>(
        ApiConfig.fieldHierarchySetManager(targetId),
        data: {'managerId': selected.managerId},
      );
      _toast('Manager updated successfully');
      await _loadAll();
    } on DioException catch (e) {
      _toast(_dioMessage(e), isError: true);
    } catch (e) {
      _toast('Failed to assign manager: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Field Sales Org Chart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: KLoading())
          : _body(),
    );
  }

  Widget _body() {
    final rows = _buildTree();
    if (rows.isEmpty) {
      return const KEmptyState(
        icon: Icons.account_tree_outlined,
        title: 'No field users in org chart',
        subtitle: 'Add field sales users and assign their reporting hierarchy.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: rows.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (ctx, i) {
          final row = rows[i];
          final node = row.node;
          final mgr = _managerId(node);
          final managerName = (mgr != null && mgr.isNotEmpty)
              ? _nodes
                  .firstWhere(
                    (n) => _userId(n) == mgr,
                    orElse: () => const {},
                  )['fullName']
                  ?.toString()
              : null;
          final role = node['role']?.toString();
          final isTop = managerName == null || managerName.isEmpty;

          return Padding(
            padding: EdgeInsetsDirectional.only(start: 20.0 * row.depth),
            child: KCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: KColors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      row.depth == 0 ? Icons.military_tech_outlined : Icons.person_outline,
                      color: KColors.primary,
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
                              _name(node),
                              style: KTypography.titleMedium,
                            ),
                            KSpacing.hGapSm,
                            if (role != null && role.isNotEmpty)
                              KStatusChip(
                                status: role,
                                label: role,
                              ),
                          ],
                        ),
                        KSpacing.vGapXxs,
                        Row(
                          children: [
                            Icon(
                              isTop ? Icons.star_border : Icons.subdirectory_arrow_right,
                              size: 14,
                              color: KColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isTop ? 'Top of hierarchy' : 'Reports to $managerName',
                              style: KTypography.bodySmall.copyWith(
                                color: KColors.textSecondary,
                                fontStyle: isTop ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  KButton.outlined(
                    label: 'Manager',
                    icon: Icons.account_tree_outlined,
                    size: KButtonSize.small,
                    onPressed: () => _assignManager(node),
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

class _TreeRow {
  final Map<String, dynamic> node;
  final int depth;
  const _TreeRow({required this.node, required this.depth});
}

class _ManagerChoice {
  final String? managerId;
  const _ManagerChoice(this.managerId);
}

