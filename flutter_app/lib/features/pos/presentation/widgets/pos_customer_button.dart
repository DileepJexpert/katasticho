import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../contacts/presentation/contact_picker_sheet.dart';
import '../../data/pos_cart_state.dart';

/// Customer selector button for the POS AppBar.
/// Shows "Walk-in" by default, selected customer name + phone when chosen.
/// Tap to open contact picker, long-press to clear.
class PosCustomerButton extends ConsumerWidget {
  const PosCustomerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    final hasCustomer = cart.hasCustomer;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onLongPress: hasCustomer
          ? () {
              ref.read(posCartProvider.notifier).clearContact();
            }
          : null,
      child: ActionChip(
        avatar: Icon(
          hasCustomer ? Icons.person : Icons.person_add_alt_1,
          size: 16,
          color: hasCustomer ? cs.primary : cs.onSurfaceVariant,
        ),
        label: Text(
          hasCustomer
              ? _formatCustomer(cart.contactName, cart.contactPhone)
              : 'Walk-in',
          style: KTypography.labelSmall.copyWith(
            color: hasCustomer ? cs.primary : cs.onSurfaceVariant,
            fontWeight: hasCustomer ? FontWeight.w600 : FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: hasCustomer
            ? cs.primary.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest,
        side: BorderSide(
          color: hasCustomer
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant,
        ),
        onPressed: () => _pickCustomer(context, ref),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  String _formatCustomer(String? name, String? phone) {
    if (name == null || name.isEmpty) return 'Customer';
    if (phone != null && phone.isNotEmpty) {
      return '$name · $phone';
    }
    return name;
  }

  Future<void> _pickCustomer(BuildContext context, WidgetRef ref) async {
    final contact = await showContactPicker(context);
    if (contact != null) {
      ref.read(posCartProvider.notifier).setContact(
            contact['id']?.toString(),
            contact['displayName']?.toString(),
            contact['phone']?.toString(),
          );
    }
  }
}
