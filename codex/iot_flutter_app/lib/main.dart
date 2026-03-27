import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/system_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/app_logger.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Inicializando aplicacion Flutter', name: 'BOOT');

  final storageService = StorageService();
  final apiService = ApiService(storageService: storageService);

  runApp(MyApp(storageService: storageService, apiService: apiService));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.storageService,
    required this.apiService,
  });

  final StorageService storageService;
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            storageService: storageService,
            apiService: apiService,
          )..bootstrap(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SystemProvider>(
          create: (_) => SystemProvider(apiService: apiService),
          update: (_, auth, system) => system!..bindAuthProvider(auth),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'IoT Monitor',
        theme: baseTheme.copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).apply(
            bodyColor: const Color(0xFFE0E0E0),
            displayColor: const Color(0xFFE0E0E0),
          ),
          colorScheme: baseTheme.colorScheme.copyWith(
            surface: const Color(0xFF1E1E1E),
            primary: const Color(0xFF4FC3F7),
            secondary: const Color(0xFFFF9800),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1B1B1B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFFD32F2F),
            contentTextStyle: TextStyle(color: Colors.white),
          ),
        ),
        home: const _AppGate(),
      ),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (_, auth, __) {
        if (!auth.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return auth.isAuthenticated
            ? const DashboardScreen()
            : const AuthScreen();
      },
    );
  }
}
