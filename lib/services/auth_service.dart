// lib/services/auth_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {

  Future<bool> login(String email, String password) async {
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final session = response.session;
      final user    = response.user;
      if (session == null || user == null) return false;

      // Obtiene rol y nombre desde tabla usuarios
      final data = await Supabase.instance.client
          .from('usuarios')
          .select('rol, nombre')
          .eq('id', user.id)
          .single();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token',   session.accessToken);
      await prefs.setString('user_rol',    data['rol']    ?? 'cobrador');
      await prefs.setString('user_nombre', data['nombre'] ?? '');
      await prefs.setString('user_id',     user.id);

      print('✅ Login OK - rol: ${data['rol']} - token: ${session.accessToken.substring(0, 20)}...');
      return true;
    } catch (e) {
      print('❌ Error login: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ✅ Solo verifica sesión activa de Supabase
  Future<bool> isLogged() async {
    return Supabase.instance.client.auth.currentSession != null;
  }
}