import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'widgets/app_update_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env', isOptional: true);
  } catch (_) {
    // Free offline mode works without bundled environment keys.
    dotenv.testLoad();
  }

  runApp(
    const ProviderScope(
      child: PlantVerseApp(),
    ),
  );
}

class PlantVerseApp extends ConsumerWidget {
  const PlantVerseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'PlantVerse AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => AppUpdateGate(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
