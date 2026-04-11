import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env_config.dart';
import 'core/theme/k_theme.dart';
import 'routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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

    return MaterialApp.router(
      title: EnvConfig.appName,
      theme: KTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: EnvConfig.showDebugBanner,
    );
  }
}
