import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env_config.dart';
import 'core/storage/pos_database.dart';
import 'core/theme/k_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/pos/data/offline_pos_service.dart';
import 'routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Offline POS uses native SQLite — configure the platform factory first, and
  // only start the offline service where it is supported (not on web).
  initPosDatabaseFactory();
  if (posOfflineSupported) {
    OfflinePosService.instance.init();
  }

  // Log environment at startup (only in debug/profile mode)
  if (kDebugMode) {
    debugPrint('═══ Katasticho ERP ═══');
    EnvConfig.summary.forEach((k, v) => debugPrint('  $k: $v'));
    debugPrint('══════════════════════');
  }

  runApp(const ProviderScope(child: KatastichoApp()));
}

class KatastichoApp extends ConsumerWidget {
  const KatastichoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: EnvConfig.appName,
      theme: KTheme.light,
      darkTheme: KTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: EnvConfig.showDebugBanner,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
