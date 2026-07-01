// lib/services/auth_service.dart
// Este archivo se mantiene solo para compatibilidad, 
// pero ahora todo el login pasa por AuthProvider
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  // Deprecado: usa AuthProvider.login() en su lugar
  @Deprecated('Usa AuthProvider en su lugar')
  Future<bool> login(String email, String password) async {
    return false;
  }

  Future<bool> isLogged() async {
    return Supabase.instance.client.auth.currentSession != null;
  }
}
