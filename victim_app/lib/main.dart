import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:victim_app/theme/theme_provider.dart' show themeModeProvider;
import 'package:victim_app/utils/constants.dart';
import 'package:victim_app/utils/page_router.dart';
import 'package:victim_app/l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'theme/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/global_unconscious_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize global unconscious detection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalUnconsciousService.resetEmergencyFlag(); // Reset emergency flag on app start
      GlobalUnconsciousService.initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GlobalUnconsciousService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
      print('App resumed //////////////');
        GlobalUnconsciousService.onAppResumed();
        break;
      case AppLifecycleState.paused:
      print('App paused //////////////');
        GlobalUnconsciousService.onAppPaused();
        break;
      case AppLifecycleState.inactive:
        // App is inactive but still visible
        break;
      case AppLifecycleState.detached:
        // App is detached
        break;
      case AppLifecycleState.hidden:
        // App is hidden
        GlobalUnconsciousService.onAppPaused();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
