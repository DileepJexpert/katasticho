import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/biometric_models.dart';
import '../data/biometric_repository.dart';

class BiometricAttendanceScreen extends ConsumerStatefulWidget {
  const BiometricAttendanceScreen({super.key});

  @override
  ConsumerState<BiometricAttendanceScreen> createState() =>
      _BiometricAttendanceScreenState();
}

class _BiometricAttendanceScreenState
    extends ConsumerState<BiometricAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Hardware Attendance & Clock-In'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fingerprint_outlined), text: 'Live Punch Stream'),
            Tab(icon: Icon(Icons.devices_outlined), text: 'Biometric Terminals'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Logs',
            onPressed: () {
              ref.invalidate(biometricLogsProvider);
              ref.invalidate(biometricDevicesProvider);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _LivePunchStreamTab(),
          _BiometricTerminalsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: LIVE PUNCH STREAM
// ─────────────────────────────────────────────────────────────────────────────

class _LivePunchStreamTab extends ConsumerWidget {
  const _LivePunchStreamTab();

  void _showSimulateModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SimulatePunchSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(biometricLogsProvider);

    return logsAsync.when(
      loading: () => const KLoading(),
      error: (err, _) => KErrorView(
        message: 'Failed to load biometric punch logs: $err',
        onRetry: () => ref.invalidate(biometricLogsProvider),
      ),
      data: (logs) {
        return Column(
          children: [
            // Top action bar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md, vertical: KSpacing.sm),
              color: KColors.bgApp,
              child: Row(
                children: [
                  const Icon(Icons.stream, size: 18, color: KColors.primary),
                  KSpacing.hGapXs,
                  Text(
                    'Real-Time Hardware Event Stream (${logs.length} Punches)',
                    style: KTypography.labelLarge,
                  ),
                  const Spacer(),
                  KButton(
                    label: 'Simulate Terminal Punch',
                    icon: Icons.touch_app_outlined,
                    onPressed: () => _showSimulateModal(context, ref),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Logs feed list
            Expanded(
              child: logs.isEmpty
                  ? const KEmptyState(
                      icon: Icons.fingerprint,
                      title: 'No Hardware Punches Recorded',
                      subtitle:
                          'Biometric clock punches from ZKTeco / eSSL devices will stream here in real time.',
                    )
                  : ListView.separated(
                      padding: KSpacing.pagePadding,
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => KSpacing.vGapSm,
                      itemBuilder: (context, i) {
                        final log = logs[i];
                        final isCheckIn = log.punchType == 'CHECK_IN';
                        final isProcessed = log.syncStatus == 'PROCESSED';

                        IconData verifyIcon = Icons.fingerprint;
                        if (log.verifyMode == 'FACE') verifyIcon = Icons.face_retouching_natural;
                        if (log.verifyMode == 'CARD') verifyIcon = Icons.credit_card;
                        if (log.verifyMode == 'PASSWORD') verifyIcon = Icons.pin_outlined;

                        return KCard(
                          padding: const EdgeInsets.all(KSpacing.md),
                          child: Row(
                            children: [
                              // Avatar / Verify Icon
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isCheckIn
                                    ? KColors.success.withValues(alpha: 0.12)
                                    : KColors.primary.withValues(alpha: 0.12),
                                child: Icon(
                                  verifyIcon,
                                  size: 20,
                                  color: isCheckIn ? KColors.success : KColors.primary,
                                ),
                              ),
                              KSpacing.hGapMd,

                              // Employee Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          log.employeeName,
                                          style: KTypography.labelLarge
                                              .copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        KSpacing.hGapSm,
                                        Text(
                                          'PIN: ${log.biometricPin}',
                                          style: KTypography.mono(
                                              fontSize: 11,
                                              color: KColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                    KSpacing.vGapXs,
                                    Row(
                                      children: [
                                        Icon(Icons.router_outlined,
                                            size: 14, color: KColors.textHint),
                                        KSpacing.hGapXs,
                                        Text(
                                          log.deviceName,
                                          style: KTypography.caption
                                              .copyWith(color: KColors.textSecondary),
                                        ),
                                        KSpacing.hGapMd,
                                        Icon(Icons.verified_user_outlined,
                                            size: 14, color: KColors.textHint),
                                        KSpacing.hGapXs,
                                        Text(
                                          log.verifyMode,
                                          style: KTypography.caption
                                              .copyWith(color: KColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Punch Type & Status Badges
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  KStatusChip(
                                    status: isCheckIn ? 'PAID' : 'PENDING',
                                    label: isCheckIn ? '🟢 CHECK IN' : '🔴 CHECK OUT',
                                  ),
                                  KSpacing.vGapXs,
                                  Text(
                                    log.punchTime.contains('T')
                                        ? log.punchTime.split('T').last.split('.').first
                                        : log.punchTime,
                                    style: KTypography.mono(
                                        fontSize: 11,
                                        color: isProcessed
                                            ? KColors.textSecondary
                                            : KColors.warning),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIMULATE PUNCH SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _SimulatePunchSheet extends ConsumerStatefulWidget {
  const _SimulatePunchSheet();

  @override
  ConsumerState<_SimulatePunchSheet> createState() => _SimulatePunchSheetState();
}

class _SimulatePunchSheetState extends ConsumerState<_SimulatePunchSheet> {
  final _pinCtl = TextEditingController(text: '101');
  String? _selectedEmployeeId;
  String _punchType = 'AUTO';
  String _verifyMode = 'FINGERPRINT';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _pinCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final req = SimulatePunchRequestPayload(
        employeeId: _selectedEmployeeId,
        biometricPin: _pinCtl.text.trim(),
        punchType: _punchType,
        verifyMode: _verifyMode,
      );

      await ref.read(biometricRepositoryProvider).simulatePunch(req);
      ref.invalidate(biometricLogsProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hardware punch simulation recorded successfully!'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(hrEmployeesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Simulate Hardware Biometric Punch', style: KTypography.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            KSpacing.vGapMd,

            // Employee Picker dropdown
            employeesAsync.when(
              data: (employees) => DropdownButtonFormField<String>(
                initialValue: _selectedEmployeeId,
                decoration: const InputDecoration(labelText: 'Select Employee (Optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Custom PIN / Guest')),
                  ...employees.map((e) => DropdownMenuItem(
                        value: e['id']?.toString(),
                        child: Text('${e['fullName'] ?? e['name']} (${e['employeeCode'] ?? "-"})'),
                      )),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedEmployeeId = v;
                    if (v != null) {
                      final emp = employees.firstWhere((e) => e['id']?.toString() == v);
                      final code = emp['employeeCode'] ?? emp['biometricPin'];
                      if (code != null) _pinCtl.text = code.toString();
                    }
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            KSpacing.vGapSm,

            KTextField(
              label: 'Device User PIN / Card ID *',
              controller: _pinCtl,
              keyboardType: TextInputType.text,
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _punchType,
                    decoration: const InputDecoration(labelText: 'Punch Action'),
                    items: const [
                      DropdownMenuItem(value: 'AUTO', child: Text('Auto (Infer In/Out)')),
                      DropdownMenuItem(value: 'CHECK_IN', child: Text('Check In')),
                      DropdownMenuItem(value: 'CHECK_OUT', child: Text('Check Out')),
                    ],
                    onChanged: (v) => setState(() => _punchType = v!),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _verifyMode,
                    decoration: const InputDecoration(labelText: 'Biometric Mode'),
                    items: const [
                      DropdownMenuItem(value: 'FINGERPRINT', child: Text('Fingerprint 👆')),
                      DropdownMenuItem(value: 'FACE', child: Text('Face Recognition 👤')),
                      DropdownMenuItem(value: 'CARD', child: Text('RFID Card 💳')),
                      DropdownMenuItem(value: 'PASSWORD', child: Text('PIN / Keypad 🔢')),
                    ],
                    onChanged: (v) => setState(() => _verifyMode = v!),
                  ),
                ),
              ],
            ),
            KSpacing.vGapLg,

            KButton(
              label: _isSubmitting ? 'Recording Punch...' : 'Record Hardware Punch',
              icon: Icons.fingerprint,
              isLoading: _isSubmitting,
              onPressed: _submit,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: BIOMETRIC TERMINALS
// ─────────────────────────────────────────────────────────────────────────────

class _BiometricTerminalsTab extends ConsumerWidget {
  const _BiometricTerminalsTab();

  void _showAddDeviceModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddDeviceSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(biometricDevicesProvider);

    return devicesAsync.when(
      loading: () => const KLoading(),
      error: (err, _) => KErrorView(
        message: 'Failed to load biometric devices: $err',
        onRetry: () => ref.invalidate(biometricDevicesProvider),
      ),
      data: (devices) {
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Configured Biometric Clocks & Gateways', style: KTypography.h2),
                KButton(
                  label: 'Add Terminal Device',
                  icon: Icons.add,
                  onPressed: () => _showAddDeviceModal(context, ref),
                ),
              ],
            ),
            KSpacing.vGapMd,

            if (devices.isEmpty)
              const KEmptyState(
                icon: Icons.devices_other,
                title: 'No Biometric Terminals Configured',
                subtitle:
                    'Connect hardware ZKTeco, eSSL, or Realtime biometric clocks via TCP socket or Cloud ADMS.',
              )
            else
              ...devices.map((d) => _DeviceCard(device: d)),
          ],
        );
      },
    );
  }
}

class _DeviceCard extends ConsumerStatefulWidget {
  final BiometricDeviceModel device;
  const _DeviceCard({required this.device});

  @override
  ConsumerState<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends ConsumerState<_DeviceCard> {
  bool _isTesting = false;

  Future<void> _testPing() async {
    setState(() => _isTesting = true);
    try {
      final res = await ref
          .read(biometricRepositoryProvider)
          .testDeviceConnection(widget.device.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Device responded OK!'),
          backgroundColor: KColors.success,
        ),
      );
      ref.invalidate(biometricDevicesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ping failed: $e'), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Device?'),
        content: Text('Remove ${widget.device.deviceName} from attendance sync?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: KColors.error)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await ref.read(biometricRepositoryProvider).deleteDevice(widget.device.id);
        ref.invalidate(biometricDevicesProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final isOnline = d.status == 'ONLINE';

    return Container(
      margin: const EdgeInsets.only(bottom: KSpacing.md),
      child: KCard(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fingerprint, color: KColors.primary, size: 24),
                KSpacing.hGapSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.deviceName, style: KTypography.labelLarge),
                      Text(
                        '${d.location ?? "Default Location"} • Protocol: ${d.protocol}',
                        style: KTypography.caption.copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                KStatusChip(
                  status: isOnline ? 'PAID' : 'PENDING',
                  label: isOnline ? 'ONLINE' : 'OFFLINE',
                ),
              ],
            ),
            KSpacing.vGapSm,
            const Divider(),
            KSpacing.vGapXs,

            // Connection Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Network Socket: ${d.deviceIp ?? "Dynamic Cloud"} : ${d.port}',
                  style: KTypography.mono(fontSize: 12),
                ),
                if (d.serialNumber != null)
                  Text(
                    'SN: ${d.serialNumber}',
                    style: KTypography.mono(fontSize: 12, color: KColors.textSecondary),
                  ),
              ],
            ),
            KSpacing.vGapSm,

            // Cloud ADMS Webhook Push URL
            if (d.cloudWebhookToken != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KColors.bgApp,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 16, color: KColors.primary),
                    KSpacing.hGapXs,
                    Expanded(
                      child: Text(
                        'Cloud Push Token: ${d.cloudWebhookToken}',
                        style: KTypography.mono(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: 'Copy Cloud Webhook URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: '/api/v1/biometric/adms/${d.cloudWebhookToken}/iclock/cdata',
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ADMS Webhook path copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              KSpacing.vGapSm,
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16, color: KColors.error),
                  label: const Text('Remove', style: TextStyle(color: KColors.error)),
                  onPressed: _delete,
                ),
                KSpacing.hGapSm,
                KButton(
                  label: _isTesting ? 'Pinging...' : 'Test Connection',
                  icon: Icons.network_ping,
                  isLoading: _isTesting,
                  onPressed: _testPing,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD DEVICE MODAL SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _AddDeviceSheet extends ConsumerStatefulWidget {
  const _AddDeviceSheet();

  @override
  ConsumerState<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends ConsumerState<_AddDeviceSheet> {
  final _nameCtl = TextEditingController();
  final _ipCtl = TextEditingController(text: '192.168.1.201');
  final _portCtl = TextEditingController(text: '4370');
  final _snCtl = TextEditingController();
  final _locationCtl = TextEditingController(text: 'Main Entrance');
  String _protocol = 'ZK_TCP';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _ipCtl.dispose();
    _portCtl.dispose();
    _snCtl.dispose();
    _locationCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device name is required')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final req = RegisterBiometricDeviceRequest(
        deviceName: name,
        deviceIp: _ipCtl.text.trim().isNotEmpty ? _ipCtl.text.trim() : null,
        port: int.tryParse(_portCtl.text.trim()) ?? 4370,
        serialNumber: _snCtl.text.trim().isNotEmpty ? _snCtl.text.trim() : null,
        protocol: _protocol,
        location: _locationCtl.text.trim().isNotEmpty ? _locationCtl.text.trim() : null,
      );

      await ref.read(biometricRepositoryProvider).registerDevice(req);
      ref.invalidate(biometricDevicesProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric device registered successfully!'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Add Biometric Attendance Device', style: KTypography.h2),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            KSpacing.vGapMd,

            KTextField(
              label: 'Device Name *',
              hint: 'e.g. Main Entrance Turnstile ZKTeco',
              controller: _nameCtl,
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: KTextField(
                    label: 'Device IP Address',
                    hint: '192.168.1.201',
                    controller: _ipCtl,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  flex: 2,
                  child: KTextField(
                    label: 'TCP Port',
                    hint: '4370',
                    controller: _portCtl,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Serial Number (SN)',
                    hint: 'e.g. ZK987654321',
                    controller: _snCtl,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _protocol,
                    decoration: const InputDecoration(labelText: 'Protocol'),
                    items: const [
                      DropdownMenuItem(value: 'ZK_TCP', child: Text('ZKTeco TCP Socket')),
                      DropdownMenuItem(value: 'ADMS_HTTP', child: Text('eSSL / ADMS Cloud Push')),
                    ],
                    onChanged: (v) => setState(() => _protocol = v!),
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,

            KTextField(
              label: 'Location / Gate',
              hint: 'e.g. Factory Main Gate / Counter',
              controller: _locationCtl,
            ),
            KSpacing.vGapLg,

            KButton(
              label: _isSaving ? 'Registering Device...' : 'Register Device',
              icon: Icons.save,
              isLoading: _isSaving,
              onPressed: _save,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
