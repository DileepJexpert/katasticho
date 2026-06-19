import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/auth/auth_state.dart';
import '../data/ai_settings_repository.dart';

// ── Model definitions ─────────────────────────────────────────────────────────

class _ModelInfo {
  final String id;
  final String label;
  final String description;
  final bool isCloud;

  const _ModelInfo({
    required this.id,
    required this.label,
    required this.description,
    this.isCloud = false,
  });
}

const _claudeModels = [
  _ModelInfo(
    id: 'claude-sonnet-4-20250514',
    label: 'Claude Sonnet 4.6',
    description: 'Best quality for Indian bills & GST. Requires Anthropic API key.',
    isCloud: true,
  ),
  _ModelInfo(
    id: 'claude-haiku-4-5-20251001',
    label: 'Claude Haiku 4.5',
    description: 'Faster & cheaper than Sonnet. Good for simple receipts.',
    isCloud: true,
  ),
];


// ── State ─────────────────────────────────────────────────────────────────────

class _AiSettingsState {
  final AiModelSettings? settings;
  final bool isLoading;
  final bool isSaving;
  final bool isTesting;
  final String? error;
  final String? testResult;
  final bool testSuccess;

  const _AiSettingsState({
    this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.isTesting = false,
    this.error,
    this.testResult,
    this.testSuccess = false,
  });

  _AiSettingsState copyWith({
    AiModelSettings? settings,
    bool? isLoading,
    bool? isSaving,
    bool? isTesting,
    String? error,
    String? testResult,
    bool? testSuccess,
  }) => _AiSettingsState(
    settings: settings ?? this.settings,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    isTesting: isTesting ?? this.isTesting,
    error: error,
    testResult: testResult,
    testSuccess: testSuccess ?? this.testSuccess,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AiModelSettingsScreen extends ConsumerStatefulWidget {
  const AiModelSettingsScreen({super.key});

  @override
  ConsumerState<AiModelSettingsScreen> createState() => _AiModelSettingsScreenState();
}

class _AiModelSettingsScreenState extends ConsumerState<AiModelSettingsScreen> {
  _AiSettingsState _state = const _AiSettingsState(isLoading: true);

  // Editable fields
  String _provider = 'CLAUDE';
  String _modelName = 'claude-sonnet-4-20250514';
  final _baseUrlController = TextEditingController(text: 'http://localhost:11434');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(aiSettingsRepositoryProvider);
      final s = await repo.getSettings();
      setState(() {
        _provider = s.provider;
        _modelName = s.modelName;
        if (s.baseUrl != null) _baseUrlController.text = s.baseUrl!;
        _state = _state.copyWith(settings: s, isLoading: false);
      });
      // If already on a local provider, pre-fill the installed-models picker.
      if (s.provider != 'CLAUDE') _detectModels(silent: true);
    } catch (e) {
      setState(() => _state = _state.copyWith(isLoading: false, error: 'Failed to load settings'));
    }
  }

  Future<void> _save() async {
    if (_provider != 'CLAUDE' && _baseUrlController.text.trim().isEmpty) {
      setState(() => _state = _state.copyWith(error: 'Server URL is required'));
      return;
    }
    setState(() => _state = _state.copyWith(isSaving: true, error: null, testResult: null));
    try {
      final repo = ref.read(aiSettingsRepositoryProvider);
      final updated = await repo.updateSettings(AiModelSettings(
        provider: _provider,
        modelName: _modelName,
        baseUrl: _provider != 'CLAUDE' ? _baseUrlController.text.trim() : null,
      ));
      setState(() => _state = _state.copyWith(settings: updated, isSaving: false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI settings saved'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      setState(() => _state = _state.copyWith(isSaving: false, error: 'Failed to save settings'));
    }
  }

  Future<void> _testConnection() async {
    final url = _baseUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _state = _state.copyWith(error: 'Enter the server URL first'));
      return;
    }
    setState(() => _state = _state.copyWith(isTesting: true, testResult: null, error: null));
    final repo = ref.read(aiSettingsRepositoryProvider);
    final ok = await repo.testConnection(url);
    // On a successful test, also pull the installed model list for the picker.
    if (ok) await _detectModels(silent: true);
    setState(() => _state = _state.copyWith(
      isTesting: false,
      testResult: ok ? 'Connected — found ${_detectedModels.length} installed model(s)'
                     : 'Cannot reach the server at $url',
      testSuccess: ok,
    ));
  }

  // Models installed on the local server (what `ollama list` shows).
  List<String> _detectedModels = [];
  bool _detecting = false;

  Future<void> _detectModels({bool silent = false}) async {
    final url = _baseUrlController.text.trim();
    if (url.isEmpty) {
      if (!silent) {
        setState(() => _state = _state.copyWith(error: 'Enter the server URL first'));
      }
      return;
    }
    if (!silent) setState(() => _detecting = true);
    final repo = ref.read(aiSettingsRepositoryProvider);
    final models = await repo.listInstalledModels(url);
    if (!mounted) return;
    setState(() {
      _detectedModels = models;
      _detecting = false;
      if (!silent && models.isEmpty) {
        _state = _state.copyWith(error: 'No models found — is the server running? (try "ollama serve")');
      }
    });
  }

  bool get _canEdit {
    final role = ref.watch(authProvider).role ?? '';
    return role == 'OWNER' || role == 'ADMIN';
  }

  bool get _hasChanges {
    final s = _state.settings;
    if (s == null) return false;
    if (_provider != s.provider || _modelName != s.modelName) return true;
    if (_provider != 'CLAUDE') {
      final savedUrl = s.baseUrl ?? 'http://localhost:11434';
      return _baseUrlController.text.trim() != savedUrl;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI & Scanning Model'),
        actions: [
          if (_canEdit && _hasChanges)
            TextButton(
              onPressed: _state.isSaving ? null : _save,
              child: _state.isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: KSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  _InfoBanner(),
                  KSpacing.vGapLg,

                  // Provider selector
                  Text('Provider', style: KTypography.h3),
                  KSpacing.vGapSm,
                  _ProviderSelector(
                    selected: _provider,
                    enabled: _canEdit,
                    onChanged: (p) => setState(() {
                      _provider = p;
                      _modelName = p == 'CLAUDE'
                          ? 'claude-sonnet-4-20250514'
                          : (_detectedModels.isNotEmpty
                              ? _detectedModels.first
                              : 'llama3.2:3b');
                      _detectedModels = [];
                      _state = _state.copyWith(testResult: null, error: null);
                    }),
                  ),
                  KSpacing.vGapLg,

                  // Model selection
                  Text('Model', style: KTypography.h3),
                  KSpacing.vGapSm,
                  _provider == 'CLAUDE'
                      ? _ModelList(
                          models: _claudeModels,
                          selected: _modelName,
                          enabled: _canEdit,
                          onSelect: (m) => setState(() => _modelName = m),
                        )
                      : _LocalModelPicker(
                          modelName: _modelName,
                          detected: _detectedModels,
                          detecting: _detecting,
                          enabled: _canEdit,
                          onDetect: _canEdit ? () => _detectModels() : null,
                          onModelChanged: (m) => setState(() => _modelName = m),
                        ),
                  KSpacing.vGapLg,

                  // Local server config (Ollama / OpenAI-compatible)
                  if (_provider != 'CLAUDE') ...[
                    Text(_provider == 'OLLAMA'
                            ? 'Ollama Server'
                            : 'Local Server (OpenAI-compatible)',
                        style: KTypography.h3),
                    KSpacing.vGapSm,
                    _OllamaConfig(
                      controller: _baseUrlController,
                      enabled: _canEdit,
                      isTesting: _state.isTesting,
                      testResult: _state.testResult,
                      testSuccess: _state.testSuccess,
                      onTest: _canEdit ? _testConnection : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    KSpacing.vGapLg,
                  ],

                  // Error
                  if (_state.error != null) ...[
                    KErrorBanner(message: _state.error!),
                    KSpacing.vGapMd,
                  ],

                  // Save button (also at bottom for convenience)
                  if (_canEdit)
                    SizedBox(
                      width: double.infinity,
                      child: KButton(
                        label: 'Save Settings',
                        icon: Icons.save_outlined,
                        fullWidth: true,
                        isLoading: _state.isSaving,
                        onPressed: _hasChanges ? _save : null,
                      ),
                    )
                  else
                    KCard(
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 16, color: KColors.textHint),
                          KSpacing.hGapSm,
                          Text('Only OWNER and ADMIN can change AI settings',
                              style: KTypography.bodySmall),
                        ],
                      ),
                    ),
                  KSpacing.vGapXl,
                ],
              ),
            ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KColors.primary.withValues(alpha: 0.07),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: KColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: KColors.primary, size: 20),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('OCR Model for Bill & Label Scanning',
                    style: KTypography.labelMedium),
                KSpacing.vGapXs,
                Text(
                  'This model is used when scanning purchase bills and product labels. '
                  'Claude gives best results. Ollama models run on your own server — free but require setup.',
                  style: KTypography.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderSelector extends StatelessWidget {
  final String selected;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _ProviderSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProviderCard(
            label: 'Claude',
            subtitle: 'Anthropic API\nBest quality',
            icon: Icons.cloud,
            iconColor: KColors.accent,
            selected: selected == 'CLAUDE',
            enabled: enabled,
            onTap: () => onChanged('CLAUDE'),
          ),
        ),
        KSpacing.hGapSm,
        Expanded(
          child: _ProviderCard(
            label: 'Ollama',
            subtitle: 'Self-hosted\nFree & private',
            icon: Icons.computer,
            iconColor: KColors.success,
            selected: selected == 'OLLAMA',
            enabled: enabled,
            onTap: () => onChanged('OLLAMA'),
          ),
        ),
        KSpacing.hGapSm,
        Expanded(
          child: _ProviderCard(
            label: 'OpenAI-compat',
            subtitle: 'vLLM / LM Studio\nllama.cpp',
            icon: Icons.dns_outlined,
            iconColor: KColors.warning,
            selected: selected == 'OPENAI_COMPAT',
            enabled: enabled,
            onTap: () => onChanged('OPENAI_COMPAT'),
          ),
        ),
      ],
    );
  }
}

/// Model picker for a local provider — a free-text model name plus a
/// "Detect installed models" button that lists what's actually on the server
/// (Ollama's `/api/tags`) as tappable chips.
class _LocalModelPicker extends StatelessWidget {
  final String modelName;
  final List<String> detected;
  final bool detecting;
  final bool enabled;
  final VoidCallback? onDetect;
  final ValueChanged<String> onModelChanged;

  const _LocalModelPicker({
    required this.modelName,
    required this.detected,
    required this.detecting,
    required this.enabled,
    required this.onDetect,
    required this.onModelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey(modelName),
                initialValue: modelName,
                enabled: enabled,
                decoration: const InputDecoration(
                  labelText: 'Model name',
                  hintText: 'e.g. qwen2.5-coder:7b',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: onModelChanged,
              ),
            ),
            KSpacing.hGapSm,
            OutlinedButton.icon(
              onPressed: enabled && !detecting ? onDetect : null,
              icon: detecting
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search, size: 16),
              label: const Text('Detect'),
            ),
          ],
        ),
        if (detected.isNotEmpty) ...[
          KSpacing.vGapSm,
          Text('Installed on your server — tap to use:',
              style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
          KSpacing.vGapXs,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in detected)
                ChoiceChip(
                  label: Text(m),
                  selected: m == modelName,
                  onSelected: enabled ? (_) => onModelChanged(m) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: KColors.primary, width: 2)
        : Border.all(color: KColors.divider);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? KColors.primary.withValues(alpha: 0.06)
              : Theme.of(context).cardColor,
          borderRadius: KSpacing.borderRadiusMd,
          border: border,
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? KColors.primary : iconColor, size: 28),
            KSpacing.vGapSm,
            Text(label,
                style: selected ? KTypography.labelLarge : KTypography.bodyMedium),
            Text(subtitle,
                style: KTypography.bodySmall.copyWith(color: KColors.textHint),
                textAlign: TextAlign.center),
            if (selected) ...[
              KSpacing.vGapXs,
              const Icon(Icons.check_circle, color: KColors.primary, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelList extends StatelessWidget {
  final List<_ModelInfo> models;
  final String selected;
  final bool enabled;
  final ValueChanged<String> onSelect;

  const _ModelList({
    required this.models,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (value) {
        if (enabled && value != null) onSelect(value);
      },
      child: Column(
        children: models
            .map((m) => _ModelTile(
                  model: m,
                  selected: m.id == selected,
                  enabled: enabled,
                  onSelect: () => onSelect(m.id),
                ))
            .toList(),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final _ModelInfo model;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;

  const _ModelTile({
    required this.model,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: enabled ? onSelect : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? KColors.primary.withValues(alpha: 0.06)
                : Theme.of(context).cardColor,
            borderRadius: KSpacing.borderRadiusMd,
            border: selected
                ? Border.all(color: KColors.primary, width: 2)
                : Border.all(color: KColors.divider),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: model.id,
                enabled: enabled,
                activeColor: KColors.primary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(model.label, style: KTypography.labelMedium),
                        ),
                        if (model.isCloud)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: KColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('Cloud',
                                style: KTypography.labelSmall
                                    .copyWith(color: KColors.accent)),
                          ),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(model.description, style: KTypography.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OllamaConfig extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isTesting;
  final String? testResult;
  final bool testSuccess;
  final VoidCallback? onTest;
  final ValueChanged<String> onChanged;

  const _OllamaConfig({
    required this.controller,
    required this.enabled,
    required this.isTesting,
    this.testResult,
    required this.testSuccess,
    this.onTest,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Server URL', style: KTypography.labelMedium),
          KSpacing.vGapSm,
          TextField(
            controller: controller,
            enabled: enabled,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: 'http://localhost:11434',
              prefixIcon: Icon(Icons.link),
              helperText:
                  'URL where Ollama is running. Must be accessible from the server.',
            ),
            keyboardType: TextInputType.url,
          ),
          KSpacing.vGapMd,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isTesting ? null : onTest,
              icon: isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering),
              label: Text(isTesting ? 'Testing...' : 'Test Connection'),
            ),
          ),
          if (testResult != null) ...[
            KSpacing.vGapSm,
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: testSuccess
                    ? KColors.success.withValues(alpha: 0.1)
                    : KColors.error.withValues(alpha: 0.1),
                borderRadius: KSpacing.borderRadiusSm,
              ),
              child: Row(
                children: [
                  Icon(
                    testSuccess ? Icons.check_circle : Icons.error_outline,
                    color: testSuccess ? KColors.success : KColors.error,
                    size: 16,
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      testResult!,
                      style: KTypography.bodySmall.copyWith(
                        color: testSuccess ? KColors.success : KColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          KSpacing.vGapMd,
          // Install guide
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KColors.textHint.withValues(alpha: 0.05),
              borderRadius: KSpacing.borderRadiusSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quick Setup', style: KTypography.labelSmall),
                KSpacing.vGapXs,
                Text(
                  '1. Install Ollama from ollama.com\n'
                  '2. Run: ollama pull llama3.2-vision\n'
                  '3. Ollama starts automatically on port 11434',
                  style: KTypography.bodySmall.copyWith(
                    fontFamily: 'monospace',
                    color: KColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
