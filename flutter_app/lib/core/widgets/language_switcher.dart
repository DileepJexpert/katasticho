import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/locale_controller.dart';

/// App-bar language switcher — pick English / हिन्दी / العربية / Kiswahili.
/// Choosing Arabic flips the whole app to RTL automatically. "System default"
/// reverts to the device language. The choice persists across reloads.
class LanguageSwitcher extends ConsumerWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final controller = ref.read(localeProvider.notifier);

    return PopupMenuButton<String?>(
      tooltip: 'Language',
      icon: const Icon(Icons.translate_rounded),
      position: PopupMenuPosition.under,
      onSelected: (code) =>
          controller.setLocale(code == null ? null : Locale(code)),
      itemBuilder: (context) => [
        _row(null, 'System default', current == null),
        const PopupMenuDivider(),
        for (final entry in LocaleController.supported.entries)
          _row(entry.key, entry.value,
              current?.languageCode == entry.key),
      ],
    );
  }

  PopupMenuItem<String?> _row(String? code, String label, bool selected) {
    return PopupMenuItem<String?>(
      value: code,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (selected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_rounded, size: 18),
          ],
        ],
      ),
    );
  }
}
