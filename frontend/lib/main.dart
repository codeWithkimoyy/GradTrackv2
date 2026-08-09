import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'config/app_theme.dart';
import 'config/firebase_options.dart';
import 'constants/app_constants.dart';
import 'providers/execution_trace_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: 'assets/.env');
  final firebaseInitialized = DefaultFirebaseOptions.isConfigured
      ? await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).then((_) => true).catchError((_) => false)
      : false;

  if (firebaseInitialized && kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      webExperimentalForceLongPolling: true,
    );
  }

  if (!kDebugMode && firebaseInitialized) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(ProviderScope(
    observers: [ExecutionTraceObserver()],
    child: const GradTrackApp(),
  ));
}

class GradTrackApp extends ConsumerWidget {
  const GradTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(effectiveThemeModeProvider),
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child ?? const SizedBox.shrink(),
        breakpoints: const [
          Breakpoint(start: 0, end: 480, name: MOBILE),
          Breakpoint(start: 481, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
          Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
    );
  }
}
