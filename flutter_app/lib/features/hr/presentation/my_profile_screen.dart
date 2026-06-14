import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../routing/app_router.dart';

/// Employee management — Core HR module 2 UI: a self-service "My Profile" hub.
/// Shows the payroll employee basics, lets the user edit their own personal /
/// emergency details, and links out to the other HR self-service screens.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  bool _loading = true;
  Map<String, dynamic> _employee = {};
  Map<String, dynamic> _profile = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.hrProfileMe);
      final data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (!mounted) return;
      setState(() {
        _employee = (data['employee'] as Map?)?.cast<String, dynamic>() ?? {};
        _profile = (data['profile'] as Map?)?.cast<String, dynamic>() ?? {};
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(initial: _profile),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _edit,
        icon: const Icon(Icons.edit),
        label: const Text('Edit details'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _employeeCard(),
                  const SizedBox(height: 16),
                  _personalCard(),
                  const SizedBox(height: 16),
                  Text('Quick links',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _quickLinks(),
                ],
              ),
            ),
    );
  }

  Widget _employeeCard() {
    final name = _employee['fullName']?.toString() ?? 'Employee';
    final code = _employee['employeeCode']?.toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Theme.of(context).textTheme.titleLarge),
                  if (code != null && code.isNotEmpty)
                    Text('Code: $code',
                        style: const TextStyle(color: Colors.grey)),
                  _kv('Designation', _employee['designation']),
                  _kv('Department', _employee['department']),
                  _kv('Date of joining', _employee['dateOfJoining']),
                  _kv('Status', _employee['employmentStatus']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalCard() {
    if (_employee.isEmpty && _profile.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('No HR profile yet'),
          subtitle: Text('Tap "Edit details" to add your personal info.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal & emergency',
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            _kv('Date of birth', _profile['dateOfBirth']),
            _kv('Gender', _profile['gender']),
            _kv('Blood group', _profile['bloodGroup']),
            _kv('Marital status', _profile['maritalStatus']),
            _kv('Personal email', _profile['personalEmail']),
            _kv('Personal phone', _profile['personalPhone']),
            _kv('Address', _profile['currentAddress']),
            _kv('Emergency contact', _profile['emergencyContactName']),
            _kv('Emergency phone', _profile['emergencyContactPhone']),
            _kv('Relation', _profile['emergencyContactRelation']),
          ],
        ),
      ),
    );
  }

  Widget _quickLinks() {
    final links = <List<Object>>[
      ['Leave', Icons.beach_access, Routes.hrLeave],
      ['Attendance', Icons.fingerprint, Routes.hrAttendance],
      ['Timesheets', Icons.timer, Routes.hrTimesheets],
      ['Documents', Icons.folder_shared, Routes.hrDocuments],
      ['Help Desk', Icons.support_agent, Routes.hrHelpdesk],
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final l in links)
          SizedBox(
            width: 150,
            child: Card(
              child: InkWell(
                onTap: () => context.go(l[2] as String),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(l[1] as IconData, size: 28),
                      const SizedBox(height: 8),
                      Text(l[0] as String),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _kv(String label, Object? value) {
    final v = value?.toString();
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.initial});
  final Map<String, dynamic> initial;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final Map<String, TextEditingController> _c;
  bool _saving = false;

  static const _fields = <String, String>{
    'dateOfBirth': 'Date of birth (YYYY-MM-DD)',
    'gender': 'Gender',
    'bloodGroup': 'Blood group',
    'maritalStatus': 'Marital status',
    'personalEmail': 'Personal email',
    'personalPhone': 'Personal phone',
    'currentAddress': 'Current address',
    'emergencyContactName': 'Emergency contact name',
    'emergencyContactPhone': 'Emergency contact phone',
    'emergencyContactRelation': 'Emergency contact relation',
  };

  @override
  void initState() {
    super.initState();
    _c = {
      for (final k in _fields.keys)
        k: TextEditingController(text: widget.initial[k]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final ctrl in _c.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = {
        for (final e in _c.entries) e.key: e.value.text.trim(),
      };
      await ref.read(apiClientProvider).put(ApiConfig.hrProfileMe, data: body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit profile',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final e in _fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _c[e.key],
                  decoration: InputDecoration(
                    labelText: e.value,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: e.key == 'currentAddress' ? 2 : 1,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
