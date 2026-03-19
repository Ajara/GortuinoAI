import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'screens/login_setup_screen.dart';
import 'screens/login_page.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TamavansApp());
}

class TamavansApp extends StatelessWidget {
  const TamavansApp({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF121212);

    final theme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: backgroundColor,
      primaryColor: const Color(0xFF4FC3F7),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4FC3F7),
        brightness: Brightness.dark,
        background: backgroundColor,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'Roboto',
            bodyColor: const Color(0xFFE0E0E0),
            displayColor: const Color(0xFFE0E0E0),
          ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
      ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, DataProvider>(
          create: (_) => DataProvider(),
          update: (_, auth, data) => data!..updateAuth(auth),
        ),
      ],
      child: MaterialApp(
        title: 'Tamavans IoT',
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: const RootRouter(),
      ),
    );
  }
}

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isInitializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!auth.isAuthenticated) {
          // Si el setup nunca se ha hecho, ir a pantalla de setup
          if (!auth.setupDone) {
            return const LoginSetupScreen();
          }
          // Si el setup ya fue completado alguna vez, ir al login
          return const LoginPage();
        }

        return const DashboardScreen();
      },
    );
  }
}

