import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../data/default_account_repository.dart';

/// Settings → Accounting → Default Accounts.
///
/// Lists every {@link DefaultAccountPurpose} the backend exposes, and lets the
/// owner/accountant rebind any of them to a different Chart-of-Accounts row.
/// Empty selection on a purpose means "fall back to the seed code at posting
/// time", so the user can also clear an override by picking the placeholder.
class DefaultAccountsScreen extends ConsumerStatefulWidget {
  const DefaultAccountsScreen({super.key});

  @override
  ConsumerState<DefaultAccountsScreen> createState() =>
      _DefaultAccountsScreenState();
}

class _DefaultAccountsScreenState extends ConsumerState<DefaultAccountsScreen> {
  /// Local in-flight edits keyed by purpose. Only purposes the user touched
  /// appear here; on Save we PUT only the changed rows.
  final Map<String, String> _pending = {};
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final defaultsAsync = ref.watch(defaultAccountsProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Default Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _saving
                ? null
                : () {
                    setState(_pending.clear);
                    ref.invalidate(defaultAccountsProvider);
                    ref.invalidate(accountsProvider);
                  },
          ),
        ],
      ),
      body: defaultsAsync.when(
        loading: () => const KLoading(),
        error: (_, __) => KErrorView(
          message: 'Failed to load default accounts',
          onRetry: () => ref.invalidate(defaultAccountsProvider),
        ),
        data: (defaults) => accountsAsync.when(
          loading: () => const KLoading(),
          error: (_, __) => KErrorView(
            message: 'Failed to load chart of accounts',
            onRetry: () => ref.invalidate(accountsProvider),
          ),
          data: (accounts) => _buildBody(defaults, accounts),
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
    List<DefaultAccountDto> defaults,
    List<AccountDto> accounts,
  ) {
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
                  'These accounts are used by invoices, bills, payments and '
                  'other journal entries. Override any row to change where '
                  'postings land — defaults are restored if you clear the '
                  'override.',
                  style: KTypography.bodySmall,
                ),
              ),
            ],
          ),
        ),
        KSpacing.vGapLg,
        for (final row in defaults) ...[
          _PurposeRow(
            row: row,
            accounts: accounts,
            pendingId: _pending[row.purpose] ?? row.accountId,
            onChanged: (newId) => _onChanged(row, newId),
          ),
          KSpacing.vGapSm,
        ],
        KSpacing.vGapXl,
      ],
    );
  }

  void _onChanged(DefaultAccountDto row, String? newId) {
    setState(() {
      // Treat picking the original-bound account as "no edit".
      if (newId == null || newId == row.accountId) {
        _pending.remove(row.purpose);
      } else {
        _pending[row.purpose] = newId;
      }
    });
  }

  Future<void> _save() async {
    if (_pending.isEmpty) return;
    setState(() => _saving = true);
    try {
      final updates = _pending.entries
          .map((e) => DefaultAccountUpdate(purpose: e.key, accountId: e.value))
          .toList();
      await ref.read(defaultAccountRepositoryProvider).update(updates);
      if (!mounted) return;
      setState(() {
        _pending.clear();
        _saving = false;
      });
      ref.invalidate(defaultAccountsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default accounts updated')),
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
}

class _PurposeRow extends StatelessWidget {
  final DefaultAccountDto row;
  final List<AccountDto> accounts;
  final String? pendingId;
  final ValueChanged<String?> onChanged;

  const _PurposeRow({
    required this.row,
    required this.accounts,
    required this.pendingId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOverridden = row.overridden;
    final isDirty = pendingId != row.accountId;

    // Only offer accounts that exist; ensure pendingId is present so the
    // dropdown doesn't crash when the bound account was deleted/archived.
    final ids = accounts.map((a) => a.id).toSet();
    final selectable = pendingId != null && !ids.contains(pendingId)
        ? null
        : pendingId;

    return KCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.label, style: KTypography.labelLarge),
              ),
              if (isDirty)
                Container(
                  padding: KSpacing.chipPadding,
                  decoration: BoxDecoration(
                    color: KColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(KSpacing.radiusRound),
                  ),
                  child: Text(
                    'Unsaved',
                    style: KTypography.labelSmall.copyWith(
                      color: KColors.warning,
                    ),
                  ),
                )
              else if (isOverridden)
                Container(
                  padding: KSpacing.chipPadding,
                  decoration: BoxDecoration(
                    color: KColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(KSpacing.radiusRound),
                  ),
                  child: Text(
                    'Custom',
                    style: KTypography.labelSmall.copyWith(
                      color: KColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Default: ${row.defaultCode}',
            style: KTypography.bodySmall.copyWith(color: KColors.textHint),
          ),
          KSpacing.vGapSm,
          DropdownButtonFormField<String>(
            value: selectable,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Account',
              isDense: true,
            ),
            items: accounts
                .map((a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(a.display, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
