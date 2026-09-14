import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'config/app_theme.dart';
import 'constants/app_constants.dart';
import 'providers/auth_providers.dart';
import 'providers/execution_trace_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (_) {
    try {
      await dotenv.load(fileName: 'assets/.env.example');
    } catch (_) {
      // Gracefully continue even if .env is missing
    }
  }

  // The backend (MySQL) needs no SDK init; just restore the persisted
  // session so returning users land straight in the app.
  final api = ApiClient();
  final authService = AuthService(api: api);
  try {
    await authService.restoreSession().timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  } catch (_) {
    // Offline / unreachable backend: the app still boots and the auth
    // screens surface the connection error on sign-in.
  }

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF081B33),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Text(
              'Application Error:\n\n${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  };

  if (!kDebugMode) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
    };
  }

  runApp(ProviderScope(
    observers: [ExecutionTraceObserver()],
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authServiceProvider.overrideWithValue(authService),
    ],
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
