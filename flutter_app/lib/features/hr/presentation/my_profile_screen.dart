import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR self-service profile — Core HR module 2 UI.
/// Any logged-in employee can read their full profile and edit safe
/// fields (personal info, addresses, emergency contact, family,
/// education, experience). Manager-controlled fields (designation,
/// department, salary, statutory IDs) are read-only here.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  // When the /me lookup returns HR_EMPLOYEE_NOT_LINKED we render a friendly
  // empty-state with a "Create my profile" button instead of a dead error —
  // a fresh shop owner has no HR admin to ask.
  bool _notLinked = false;
  bool _claiming = false;

  Map<String, dynamic> get _employee =>
      (_profile?['employee'] as Map?)?.cast<String, dynamic>() ?? {};
  List<Map<String, dynamic>> get _family =>
      ((_profile?['family'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _education =>
      ((_profile?['education'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _experience =>
      ((_profile?['experience'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _notLinked = false;
    });
    final api = ref.read(apiClientProvider);
    try {
      final res = await api.get(ApiConfig.hrMyProfile);
      if (!mounted) return;
      setState(() => _profile = (res.data['data'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final code = (body is Map ? body['errorCode'] : null) ?? '';
      if (code == 'HR_EMPLOYEE_NOT_LINKED') {
        setState(() => _notLinked = true);
      } else {
        setState(() => _error = 'Failed to load profile: ${e.message ?? e}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimProfile() async {
    setState(() => _claiming = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.post('${ApiConfig.hrMyProfile}/claim');
      if (!mounted) return;
      _toast('Employee profile created');
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      _toast('Could not create profile: ${e.message ?? e}');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notLinked
              ? _NotLinkedView(
                  busy: _claiming,
                  onCreate: _claimProfile,
                )
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _headerCard(),
                      const SizedBox(height: 16),
                      _personalCard(),
                      const SizedBox(height: 16),
                      _addressCard('Current address', _employee, 'current'),
                      const SizedBox(height: 16),
                      _addressCard('Permanent address', _employee, 'permanent'),
                      const SizedBox(height: 16),
                      _emergencyCard(),
                      const SizedBox(height: 16),
                      _familyCard(),
                      const SizedBox(height: 16),
                      _educationCard(),
                      const SizedBox(height: 16),
                      _experienceCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  // ───── Header (read-only manager-set summary) ─────

  Widget _headerCard() {
    final e = _employee;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (e['fullName'] ?? '—') as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('${e['designation'] ?? '—'} · ${e['department'] ?? '—'}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (e['employeeCode'] != null)
                  Chip(label: Text('Code: ${e['employeeCode']}')),
                if (e['employmentType'] != null)
                  Chip(label: Text('${e['employmentType']}')),
                if (e['employmentStatus'] != null)
                  Chip(label: Text('${e['employmentStatus']}')),
                if (e['dateOfJoining'] != null)
                  Chip(label: Text('Joined ${e['dateOfJoining']}')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Designation, department, employment status and salary are '
              'set by HR — contact your manager to update them.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ───── Personal info ─────

  Widget _personalCard() {
    final e = _employee;
    return _section(
      title: 'Personal',
      onEdit: _editPersonal,
      rows: [
        _kv('Date of birth', e['dateOfBirth']),
        _kv('Gender', e['gender']),
        _kv('Marital status', e['maritalStatus']),
        _kv('Blood group', e['bloodGroup']),
        _kv('Nationality', e['nationality']),
        _kv('Personal email', e['personalEmail']),
        _kv('Phone', e['phone']),
      ],
    );
  }

  Future<void> _editPersonal() async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PersonalDialog(initial: _employee),
    );
    if (saved == null) return;
    await _putMe(saved);
  }

  // ───── Address ─────

  Widget _addressCard(String title, Map<String, dynamic> e, String prefix) {
    return _section(
      title: title,
      onEdit: () => _editAddress(title, prefix),
      rows: [
        _kv('Line 1', e['${prefix}AddressLine1']),
        _kv('Line 2', e['${prefix}AddressLine2']),
        _kv('City', e['${prefix}City']),
        _kv('State', e['${prefix}State']),
        _kv('Pincode', e['${prefix}Pincode']),
      ],
    );
  }

  Future<void> _editAddress(String title, String prefix) async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddressDialog(
        title: title,
        prefix: prefix,
        initial: _employee,
      ),
    );
    if (saved == null) return;
    await _putMe(saved);
  }

  // ───── Emergency ─────

  Widget _emergencyCard() {
    final e = _employee;
    return _section(
      title: 'Emergency contact',
      onEdit: _editEmergency,
      rows: [
        _kv('Name', e['emergencyContactName']),
        _kv('Relationship', e['emergencyContactRelationship']),
        _kv('Phone', e['emergencyContactPhone']),
      ],
    );
  }

  Future<void> _editEmergency() async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EmergencyDialog(initial: _employee),
    );
    if (saved == null) return;
    await _putMe(saved);
  }

  // ───── Family ─────

  Widget _familyCard() {
    return _listSection(
      title: 'Family / dependents',
      items: _family,
      onAdd: () => _editFamily(null),
      onEdit: (row) => _editFamily(row),
      onDelete: (row) => _deleteSubresource(
          ApiConfig.hrMyFamilyById(row['id'] as String), 'Family member'),
      titleOf: (r) => '${r['name'] ?? '—'} · ${r['relationship'] ?? ''}',
      subtitleOf: (r) {
        final parts = <String>[];
        if (r['dateOfBirth'] != null) parts.add('DOB ${r['dateOfBirth']}');
        if (r['dependent'] == true) parts.add('Dependent');
        if (r['phone'] != null) parts.add('${r['phone']}');
        return parts.join(' · ');
      },
    );
  }

  Future<void> _editFamily(Map<String, dynamic>? existing) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FamilyDialog(initial: existing),
    );
    if (res == null) return;
    await _saveSubresource(
      collection: ApiConfig.hrMyFamily,
      existingId: existing?['id'] as String?,
      body: res,
      itemById: ApiConfig.hrMyFamilyById,
      label: 'Family member',
    );
  }

  // ───── Education ─────

  Widget _educationCard() {
    return _listSection(
      title: 'Education',
      items: _education,
      onAdd: () => _editEducation(null),
      onEdit: (row) => _editEducation(row),
      onDelete: (row) => _deleteSubresource(
          ApiConfig.hrMyEducationById(row['id'] as String), 'Education'),
      titleOf: (r) => '${r['degree'] ?? '—'}'
          '${r['fieldOfStudy'] != null ? ' · ${r['fieldOfStudy']}' : ''}',
      subtitleOf: (r) {
        final parts = <String>[];
        if (r['institution'] != null) parts.add('${r['institution']}');
        if (r['startYear'] != null || r['endYear'] != null) {
          parts.add('${r['startYear'] ?? '?'}–${r['endYear'] ?? 'present'}');
        }
        if (r['grade'] != null) parts.add('${r['grade']}');
        return parts.join(' · ');
      },
    );
  }

  Future<void> _editEducation(Map<String, dynamic>? existing) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EducationDialog(initial: existing),
    );
    if (res == null) return;
    await _saveSubresource(
      collection: ApiConfig.hrMyEducation,
      existingId: existing?['id'] as String?,
      body: res,
      itemById: ApiConfig.hrMyEducationById,
      label: 'Education',
    );
  }

  // ───── Experience ─────

  Widget _experienceCard() {
    return _listSection(
      title: 'Prior work experience',
      items: _experience,
      onAdd: () => _editExperience(null),
      onEdit: (row) => _editExperience(row),
      onDelete: (row) => _deleteSubresource(
          ApiConfig.hrMyExperienceById(row['id'] as String), 'Experience'),
      titleOf: (r) =>
          '${r['companyName'] ?? '—'}${r['designation'] != null ? ' · ${r['designation']}' : ''}',
      subtitleOf: (r) {
        final parts = <String>[];
        if (r['fromDate'] != null || r['toDate'] != null) {
          parts.add('${r['fromDate'] ?? '?'} → ${r['toDate'] ?? 'present'}');
        }
        if (r['location'] != null) parts.add('${r['location']}');
        return parts.join(' · ');
      },
    );
  }

  Future<void> _editExperience(Map<String, dynamic>? existing) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ExperienceDialog(initial: existing),
    );
    if (res == null) return;
    await _saveSubresource(
      collection: ApiConfig.hrMyExperience,
      existingId: existing?['id'] as String?,
      body: res,
      itemById: ApiConfig.hrMyExperienceById,
      label: 'Experience',
    );
  }

  // ───── HTTP helpers ─────

  Future<void> _putMe(Map<String, dynamic> partial) async {
    final api = ref.read(apiClientProvider);
    // Merge over the current employee so the server sees a full document
    // (server-side updateMe ignores manager-controlled fields anyway).
    final merged = {..._employee, ...partial};
    try {
      await api.put(ApiConfig.hrMyProfile, data: merged);
      _toast('Profile updated');
      await _load();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _saveSubresource({
    required String collection,
    required String? existingId,
    required Map<String, dynamic> body,
    required String Function(String) itemById,
    required String label,
  }) async {
    final api = ref.read(apiClientProvider);
    try {
      if (existingId == null) {
        await api.post(collection, data: body);
        _toast('$label added');
      } else {
        await api.put(itemById(existingId), data: body);
        _toast('$label updated');
      }
      await _load();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _deleteSubresource(String url, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final api = ref.read(apiClientProvider);
    try {
      await api.delete(url);
      _toast('Removed');
      await _load();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  // ───── Layout helpers ─────

  Widget _section({
    required String title,
    required VoidCallback onEdit,
    required List<Widget> rows,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const Divider(height: 16),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _listSection({
    required String title,
    required List<Map<String, dynamic>> items,
    required VoidCallback onAdd,
    required void Function(Map<String, dynamic>) onEdit,
    required void Function(Map<String, dynamic>) onDelete,
    required String Function(Map<String, dynamic>) titleOf,
    required String Function(Map<String, dynamic>) subtitleOf,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            const Divider(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('None yet.'),
              )
            else
              ...items.map(
                (row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(titleOf(row)),
                  subtitle: subtitleOf(row).isEmpty ? null : Text(subtitleOf(row)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) =>
                        v == 'edit' ? onEdit(row) : onDelete(row),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Remove')),
                    ],
                  ),
                  onTap: () => onEdit(row),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String label, Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 140, child: Text(label)),
            const Expanded(child: Text('—', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// ───────────────────────── Dialogs ─────────────────────────

class _PersonalDialog extends StatefulWidget {
  final Map<String, dynamic> initial;
  const _PersonalDialog({required this.initial});

  @override
  State<_PersonalDialog> createState() => _PersonalDialogState();
}

class _PersonalDialogState extends State<_PersonalDialog> {
  late final TextEditingController _dob;
  late final TextEditingController _bg;
  late final TextEditingController _nat;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  String? _gender;
  String? _marital;

  @override
  void initState() {
    super.initState();
    _dob = TextEditingController(text: widget.initial['dateOfBirth']?.toString() ?? '');
    _bg = TextEditingController(text: widget.initial['bloodGroup']?.toString() ?? '');
    _nat = TextEditingController(text: widget.initial['nationality']?.toString() ?? '');
    _email = TextEditingController(text: widget.initial['personalEmail']?.toString() ?? '');
    _phone = TextEditingController(text: widget.initial['phone']?.toString() ?? '');
    _gender = widget.initial['gender']?.toString();
    _marital = widget.initial['maritalStatus']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Personal info'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _dob,
                decoration: const InputDecoration(
                  labelText: 'Date of birth (YYYY-MM-DD)',
                ),
              ),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  DropdownMenuItem(
                      value: 'PREFER_NOT_TO_SAY',
                      child: Text('Prefer not to say')),
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
              DropdownButtonFormField<String>(
                value: _marital,
                decoration: const InputDecoration(labelText: 'Marital status'),
                items: const [
                  DropdownMenuItem(value: 'SINGLE', child: Text('Single')),
                  DropdownMenuItem(value: 'MARRIED', child: Text('Married')),
                  DropdownMenuItem(value: 'DIVORCED', child: Text('Divorced')),
                  DropdownMenuItem(value: 'WIDOWED', child: Text('Widowed')),
                ],
                onChanged: (v) => setState(() => _marital = v),
              ),
              TextField(
                controller: _bg,
                decoration: const InputDecoration(labelText: 'Blood group'),
              ),
              TextField(
                controller: _nat,
                decoration: const InputDecoration(labelText: 'Nationality'),
              ),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Personal email'),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'dateOfBirth': _emptyToNull(_dob.text),
            'gender': _gender,
            'maritalStatus': _marital,
            'bloodGroup': _emptyToNull(_bg.text),
            'nationality': _emptyToNull(_nat.text),
            'personalEmail': _emptyToNull(_email.text),
            'phone': _emptyToNull(_phone.text),
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddressDialog extends StatefulWidget {
  final String title;
  final String prefix;
  final Map<String, dynamic> initial;
  const _AddressDialog({
    required this.title,
    required this.prefix,
    required this.initial,
  });

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final TextEditingController _l1;
  late final TextEditingController _l2;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pin;

  String _k(String suffix) => '${widget.prefix}$suffix';

  @override
  void initState() {
    super.initState();
    _l1 = TextEditingController(text: widget.initial[_k('AddressLine1')]?.toString() ?? '');
    _l2 = TextEditingController(text: widget.initial[_k('AddressLine2')]?.toString() ?? '');
    _city = TextEditingController(text: widget.initial[_k('City')]?.toString() ?? '');
    _state = TextEditingController(text: widget.initial[_k('State')]?.toString() ?? '');
    _pin = TextEditingController(text: widget.initial[_k('Pincode')]?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _l1,
                decoration: const InputDecoration(labelText: 'Line 1'),
              ),
              TextField(
                controller: _l2,
                decoration: const InputDecoration(labelText: 'Line 2'),
              ),
              TextField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              TextField(
                controller: _state,
                decoration: const InputDecoration(labelText: 'State'),
              ),
              TextField(
                controller: _pin,
                decoration: const InputDecoration(labelText: 'Pincode'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            _k('AddressLine1'): _emptyToNull(_l1.text),
            _k('AddressLine2'): _emptyToNull(_l2.text),
            _k('City'): _emptyToNull(_city.text),
            _k('State'): _emptyToNull(_state.text),
            _k('Pincode'): _emptyToNull(_pin.text),
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmergencyDialog extends StatefulWidget {
  final Map<String, dynamic> initial;
  const _EmergencyDialog({required this.initial});

  @override
  State<_EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<_EmergencyDialog> {
  late final TextEditingController _name;
  late final TextEditingController _rel;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: widget.initial['emergencyContactName']?.toString() ?? '');
    _rel = TextEditingController(
        text: widget.initial['emergencyContactRelationship']?.toString() ?? '');
    _phone = TextEditingController(
        text: widget.initial['emergencyContactPhone']?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emergency contact'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _rel,
              decoration: const InputDecoration(labelText: 'Relationship'),
            ),
            TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'emergencyContactName': _emptyToNull(_name.text),
            'emergencyContactRelationship': _emptyToNull(_rel.text),
            'emergencyContactPhone': _emptyToNull(_phone.text),
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _FamilyDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _FamilyDialog({this.initial});

  @override
  State<_FamilyDialog> createState() => _FamilyDialogState();
}

class _FamilyDialogState extends State<_FamilyDialog> {
  late final TextEditingController _name;
  late final TextEditingController _dob;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  String _relationship = 'SPOUSE';
  bool _dependent = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const {};
    _name = TextEditingController(text: i['name']?.toString() ?? '');
    _dob = TextEditingController(text: i['dateOfBirth']?.toString() ?? '');
    _phone = TextEditingController(text: i['phone']?.toString() ?? '');
    _notes = TextEditingController(text: i['notes']?.toString() ?? '');
    _relationship = (i['relationship'] as String?) ?? 'SPOUSE';
    _dependent = (i['dependent'] as bool?) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add family member' : 'Edit family'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              DropdownButtonFormField<String>(
                value: _relationship,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: const [
                  DropdownMenuItem(value: 'SPOUSE', child: Text('Spouse')),
                  DropdownMenuItem(value: 'CHILD', child: Text('Child')),
                  DropdownMenuItem(value: 'FATHER', child: Text('Father')),
                  DropdownMenuItem(value: 'MOTHER', child: Text('Mother')),
                  DropdownMenuItem(value: 'SIBLING', child: Text('Sibling')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) =>
                    setState(() => _relationship = v ?? 'OTHER'),
              ),
              TextField(
                controller: _dob,
                decoration: const InputDecoration(
                  labelText: 'Date of birth (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              SwitchListTile(
                title: const Text('Dependent'),
                contentPadding: EdgeInsets.zero,
                value: _dependent,
                onChanged: (v) => setState(() => _dependent = v),
              ),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, {
                    'name': _name.text.trim(),
                    'relationship': _relationship,
                    'dateOfBirth': _emptyToNull(_dob.text),
                    'phone': _emptyToNull(_phone.text),
                    'dependent': _dependent,
                    'notes': _emptyToNull(_notes.text),
                  }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EducationDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _EducationDialog({this.initial});

  @override
  State<_EducationDialog> createState() => _EducationDialogState();
}

class _EducationDialogState extends State<_EducationDialog> {
  late final TextEditingController _degree;
  late final TextEditingController _field;
  late final TextEditingController _inst;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _grade;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const {};
    _degree = TextEditingController(text: i['degree']?.toString() ?? '');
    _field = TextEditingController(text: i['fieldOfStudy']?.toString() ?? '');
    _inst = TextEditingController(text: i['institution']?.toString() ?? '');
    _start = TextEditingController(text: i['startYear']?.toString() ?? '');
    _end = TextEditingController(text: i['endYear']?.toString() ?? '');
    _grade = TextEditingController(text: i['grade']?.toString() ?? '');
    _notes = TextEditingController(text: i['notes']?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add education' : 'Edit education'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _degree,
                decoration: const InputDecoration(labelText: 'Degree *'),
              ),
              TextField(
                controller: _field,
                decoration: const InputDecoration(labelText: 'Field of study'),
              ),
              TextField(
                controller: _inst,
                decoration: const InputDecoration(labelText: 'Institution'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _start,
                      decoration:
                          const InputDecoration(labelText: 'Start year'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _end,
                      decoration: const InputDecoration(labelText: 'End year'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _grade,
                decoration: const InputDecoration(labelText: 'Grade'),
              ),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _degree.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, {
                    'degree': _degree.text.trim(),
                    'fieldOfStudy': _emptyToNull(_field.text),
                    'institution': _emptyToNull(_inst.text),
                    'startYear': _intOrNull(_start.text),
                    'endYear': _intOrNull(_end.text),
                    'grade': _emptyToNull(_grade.text),
                    'notes': _emptyToNull(_notes.text),
                  }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ExperienceDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _ExperienceDialog({this.initial});

  @override
  State<_ExperienceDialog> createState() => _ExperienceDialogState();
}

class _ExperienceDialogState extends State<_ExperienceDialog> {
  late final TextEditingController _company;
  late final TextEditingController _desg;
  late final TextEditingController _from;
  late final TextEditingController _to;
  late final TextEditingController _loc;
  late final TextEditingController _resp;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const {};
    _company = TextEditingController(text: i['companyName']?.toString() ?? '');
    _desg = TextEditingController(text: i['designation']?.toString() ?? '');
    _from = TextEditingController(text: i['fromDate']?.toString() ?? '');
    _to = TextEditingController(text: i['toDate']?.toString() ?? '');
    _loc = TextEditingController(text: i['location']?.toString() ?? '');
    _resp = TextEditingController(
        text: i['responsibilities']?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add experience' : 'Edit experience'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _company,
                decoration: const InputDecoration(labelText: 'Company *'),
              ),
              TextField(
                controller: _desg,
                decoration: const InputDecoration(labelText: 'Designation'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _from,
                      decoration: const InputDecoration(
                        labelText: 'From (YYYY-MM-DD)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _to,
                      decoration: const InputDecoration(
                        labelText: 'To (YYYY-MM-DD)',
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _loc,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              TextField(
                controller: _resp,
                decoration:
                    const InputDecoration(labelText: 'Responsibilities'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _company.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, {
                    'companyName': _company.text.trim(),
                    'designation': _emptyToNull(_desg.text),
                    'fromDate': _emptyToNull(_from.text),
                    'toDate': _emptyToNull(_to.text),
                    'location': _emptyToNull(_loc.text),
                    'responsibilities': _emptyToNull(_resp.text),
                  }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

String? _emptyToNull(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

int? _intOrNull(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  return int.tryParse(t);
}

/// Friendly empty-state shown when the logged-in user has no payroll Employee
/// linked yet. Lets them claim a fresh profile in one tap — the typical case
/// for a shop owner who signed up as OWNER and has no HR admin to ask.
class _NotLinkedView extends StatelessWidget {
  final bool busy;
  final VoidCallback onCreate;

  const _NotLinkedView({required this.busy, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text(
                'Set up your employee profile',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your login is not linked to an employee record yet. '
                'Tap the button below to create one using your account '
                'name and email — it takes a second.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : onCreate,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.person_add_outlined),
                label: Text(busy ? 'Creating…' : 'Create my employee profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
