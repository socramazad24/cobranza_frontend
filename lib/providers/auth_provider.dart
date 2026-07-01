import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Login con Supabase Auth
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final session = response.session;
      final user = response.user;

      if (session == null || user == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Consultar rol y nombre desde tabla usuarios
      final data = await supabase
          .from('usuarios')
          .select('rol, nombre')
          .eq('id', user.id)
          .single();

      // 3. Guardar TODOS los datos necesarios en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwttoken', session.accessToken);
      await prefs.setString('userrol', data['rol'] ?? 'cobrador');
      await prefs.setString('usernombre', data['nombre'] ?? '');
      await prefs.setString('userid', user.id);

      debugPrint('Login OK - rol: ${data['rol']} - token: ${session.accessToken.substring(0, 20)}...');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error de login: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
