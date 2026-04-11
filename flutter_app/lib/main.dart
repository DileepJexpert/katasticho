import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/k_theme.dart';
import 'routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: KatastichoApp()));
}

class KatastichoApp extends ConsumerWidget {
  const KatastichoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Katasticho ERP',
      theme: KTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
