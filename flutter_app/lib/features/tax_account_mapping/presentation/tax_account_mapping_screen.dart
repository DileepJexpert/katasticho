import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../data/tax_account_mapping_repository.dart';

/// Settings → Taxes & Compliance → Tax Account Mapping.
///
/// Each TaxRate row exposes its bound output (collected) and (optionally)
/// input (recoverable) GL accounts. The input dropdown is hidden for
/// non-recoverable rates (TDS, cesses, sales tax). Saving a row sets the
/// backend's `is_gl_account_customized` flag so future seed repairs leave it
/// alone — Reset wipes the flag and re-runs the country-specific seed.
class TaxAccountMappingScreen extends ConsumerStatefulWidget {
  const TaxAccountMappingScreen({super.key});

  @override
  ConsumerState<TaxAccountMappingScreen> createState() =>
      _TaxAccountMappingScreenState();
}

class _TaxAccountMappingScreenState
    extends ConsumerState<TaxAccountMappingScreen> {
  /// Local edits keyed by taxRateId. Sentinel value `_clear` means "set
  /// this side back to NULL on the backend".
  final Map<String, _PendingMapping> _pending = {};
  bool _saving = false;
  bool _resetting = false;

  @override
  Widget build(BuildContext context) {
    final mappingsAsync = ref.watch(taxAccountMappingsProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Account Mapping'),
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            icon: const Icon(Icons.restart_alt),
            onPressed: (_saving || _resetting) ? null : _confirmReset,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: (_saving || _resetting)
                ? null
                : () {
                    setState(_pending.clear);
                    ref.invalidate(taxAccountMappingsProvider);
                    ref.invalidate(accountsProvider);
                  },
          ),
        ],
      ),
      body: mappingsAsync.when(
        loading: () => const KLoading(),
        error: (_, __) => KErrorView(
          message: 'Failed to load tax mappings',
          onRetry: () => ref.invalidate(taxAccountMappingsProvider),
        ),
        data: (mappings) => accountsAsync.when(
          loading: () => const KLoading(),
          error: (_, __) => KErrorView(
            message: 'Failed to load chart of accounts',
            onRetry: () => ref.invalidate(accountsProvider),
          ),
          data: (accounts) => _buildBody(mappings, accounts),
        ),
      ),
      bottomNavigationBar: _pending.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: KSpacing.pagePadding,
                child: Row(
                  children: [
                    Expanded(
                      child: KButton(
                        label: 'Discard',
                        variant: KButtonVariant.outlined,
                        onPressed: _saving
                            ? null
                            : () => setState(_pending.clear),
                      ),
                    ),
                    KSpacing.hGapMd,
                    Expanded(
                      child: KButton(
                        label: 'Save (${_pending.length})',
                        icon: Icons.save_outlined,
                        isLoading: _saving,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(
    List<TaxAccountMappingDto> mappings,
    List<AccountDto> accounts,
  ) {
    if (mappings.isEmpty) {
      return const KEmptyState(
        icon: Icons.percent,
        title: 'No tax rates configured',
        subtitle: 'Set up tax rates first to map them to GL accounts.',
      );
    }

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          backgroundColor: KColors.primary.withValues(alpha: 0.05),
          borderColor: KColors.primary.withValues(alpha: 0.2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: KColors.primary, size: 20),
              KSpacing.hGapSm,
              Expanded(
                child: Text(
                  'Output accounts hold tax collected on sales (a liability). '
                  'Input accounts hold recoverable tax paid on purchases (an '
                  'asset). Non-recoverable taxes (e.g. TDS) only post to the '
                  'output side.',
                  style: KTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
        KSpacing.vGapLg,
        for (final m in mappings) ...[
          _MappingRow(
            mapping: m,
            accounts: accounts,
            pending: _pending[m.taxRateId],
            onOutputChanged: (id) => _onChanged(m, output: id),
            onInputChanged: (id) => _onChanged(m, input: id),
          ),
          KSpacing.vGapSm,
        ],
        KSpacing.vGapXl,
      ],
    );
  }

  void _onChanged(
    TaxAccountMappingDto m, {
    String? output,
    String? input,
    bool outputChanged = false,
    bool inputChanged = false,
  }) {
    final existing = _pending[m.taxRateId] ??
        _PendingMapping(
          outputAccountId: m.glOutputAccountId,
          inputAccountId: m.glInputAccountId,
        );

    final newOutput = output != null || outputChanged
        ? output
        : existing.outputAccountId;
    final newInput = input != null || inputChanged
        ? input
        : existing.inputAccountId;

    final updated = _PendingMapping(
      outputAccountId: newOutput,
      inputAccountId: newInput,
    );

    setState(() {
      // If user reverts to the original values, drop the pending entry.
      if (updated.outputAccountId == m.glOutputAccountId &&
          updated.inputAccountId == m.glInputAccountId) {
        _pending.remove(m.taxRateId);
      } else {
        _pending[m.taxRateId] = updated;
      }
    });
  }

  Future<void> _save() async {
    if (_pending.isEmpty) return;
    setState(() => _saving = true);
    try {
      final updates = _pending.entries
          .map((e) => TaxAccountMappingUpdate(
                taxRateId: e.key,
                glOutputAccountId: e.value.outputAccountId,
                glInputAccountId: e.value.inputAccountId,
              ))
          .toList();
      await ref.read(taxAccountMappingRepositoryProvider).update(updates);
      if (!mounted) return;
      setState(() {
        _pending.clear();
        _saving = false;
      });
      ref.invalidate(taxAccountMappingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tax account mappings updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorParser.message(e)),
          backgroundColor: KColors.error,
        ),
      );
    }
  }

  Future<void> _confirmReset() async {
    final ok = await KDialog.confirm(
      context: context,
      title: 'Reset tax mappings?',
      message:
          'This drops every customisation and re-binds tax rates to the '
          'country-default GL accounts. Continue?',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() {
      _resetting = true;
      _pending.clear();
    });
    try {
      await ref.read(taxAccountMappingRepositoryProvider).reset();
      if (!mounted) return;
      ref.invalidate(taxAccountMappingsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tax mappings reset to defaults')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorParser.message(e)),
          backgroundColor: KColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }
}

class _PendingMapping {
  final String? outputAccountId;
  final String? inputAccountId;
  const _PendingMapping({this.outputAccountId, this.inputAccountId});
}

class _MappingRow extends StatelessWidget {
  final TaxAccountMappingDto mapping;
  final List<AccountDto> accounts;
  final _PendingMapping? pending;
  final ValueChanged<String?> onOutputChanged;
  final ValueChanged<String?> onInputChanged;

  const _MappingRow({
    required this.mapping,
    required this.accounts,
    required this.pending,
    required this.onOutputChanged,
    required this.onInputChanged,
  });

  @override
  Widget build(BuildContext context) {
    final outputId = pending?.outputAccountId ?? mapping.glOutputAccountId;
    final inputId = pending?.inputAccountId ?? mapping.glInputAccountId;
    final isDirty = pending != null;
    final ids = accounts.map((a) => a.id).toSet();

    // Defensive: if a previously-bound account was deleted, drop the value
    // so the dropdown can render its own "no selection" state.
    final outputValue = outputId == null || !ids.contains(outputId)
        ? null
        : outputId;
    final inputValue = inputId == null || !ids.contains(inputId)
        ? null
        : inputId;

    return KCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mapping.displayLabel,
                  style: KTypography.labelLarge,
                ),
              ),
              if (isDirty)
                _Pill(
                  label: 'Unsaved',
                  color: KColors.warning,
                )
              else if (mapping.customized)
                _Pill(
                  label: 'Custom',
                  color: KColors.primary,
                ),
            ],
          ),
          if (mapping.rateCode != null && mapping.rateCode!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              mapping.rateCode!,
              style: KTypography.bodySmall.copyWith(color: KColors.textHint),
            ),
          ],
          KSpacing.vGapMd,
          DropdownButtonFormField<String>(
            value: outputValue,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Output (collected) account',
              isDense: true,
            ),
            items: accounts
                .map((a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(a.display, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: onOutputChanged,
          ),
          if (mapping.recoverable) ...[
            KSpacing.vGapSm,
            DropdownButtonFormField<String>(
              value: inputValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Input (recoverable) account',
                isDense: true,
              ),
              items: accounts
                  .map((a) => DropdownMenuItem<String>(
                        value: a.id,
                        child:
                            Text(a.display, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: onInputChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: KSpacing.chipPadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(KSpacing.radiusRound),
      ),
      child: Text(
        label,
        style: KTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}
