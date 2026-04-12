import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_mode_controller.dart';

/// Three-state theme switcher (system / light / dark).
///
/// Two flavours:
///   • [ThemeModeIconButton] — single AppBar action that cycles modes
///   • [ThemeModeSegmented]  — segmented buttons for Settings screens
class ThemeModeIconButton extends ConsumerWidget {
  const ThemeModeIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);

    final (icon, tooltip) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_rounded, 'Theme: System'),
      ThemeMode.light => (Icons.light_mode_rounded, 'Theme: Light'),
      ThemeMode.dark => (Icons.dark_mode_rounded, 'Theme: Dark'),
    };

    return IconButton(
      tooltip: '$tooltip — tap to switch',
      icon: Icon(icon),
      onPressed: controller.cycle,
    );
  }
}

class ThemeModeSegmented extends ConsumerWidget {
  const ThemeModeSegmented({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('System'),
          icon: Icon(Icons.brightness_auto_rounded),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode_rounded),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode_rounded),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) => controller.setMode(s.first),
      showSelectedIcon: false,
    );
  }
}
