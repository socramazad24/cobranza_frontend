// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:frontend_flutter/screens/main_layout.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/constants.dart';
import 'utils/http_client.dart';
import 'utils/storage_keys.dart';
import 'providers/auth_provider.dart';
import 'providers/app_refresh_provider.dart';
import 'screens/login_screen.dart';
import 'widgets/network_aware_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ INICIALIZAR locale de intl ANTES de cualquier DateFormat
  await initializeDateFormatting('es_CO', null);

  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppRefreshProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Verifica sesión activa, refresca el token si está por expirar y
/// sincroniza los datos en SharedPreferences usando StorageKeys.
Future<bool> checkSession() async {
  final supabase = Supabase.instance.client;
  final session = supabase.auth.currentSession;

  if (session == null) return false;

  try {
    // Refresca el token si vence en menos de 60 segundos
    final parts = session.accessToken.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload['exp'] as int;
    final ahora = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    String accessToken = session.accessToken;
    if (exp - ahora < 60) {
      final refreshed = await supabase.auth.refreshSession();
      if (refreshed.session == null) return false;
      accessToken = refreshed.session!.accessToken;
    }

    // Trae el rol/nombre desde la tabla usuarios
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('usuarios')
        .select('rol, nombre')
        .eq('id', userId)
        .single();

    // Guarda TODO con keys unificadas
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.token, accessToken);
    await prefs.setString(StorageKeys.userId, userId);
    await prefs.setString(StorageKeys.userRol, data['rol'] ?? 'cobrador');
    await prefs.setString(StorageKeys.userNombre, data['nombre'] ?? '');

    return true;
  } catch (e) {
    debugPrint('Error en checkSession: $e');
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crédito Fácil',
      navigatorKey: ApiClient.navigatorKey,
      theme: ThemeData(
        primaryColor: const Color(0xFFE0F7FA),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFB2EBF2),
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB3E5FC),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      builder: (context, child) => NetworkAwareWidget(child: child!),
      home: FutureBuilder<bool>(
        future: checkSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == true
              ? const MainLayout()
              : const LoginScreen();
        },
      ),
    );
  }
}