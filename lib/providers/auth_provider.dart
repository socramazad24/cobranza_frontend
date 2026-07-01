// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/storage_keys.dart';

class AuthProvider with ChangeNotifier {
  final supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
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

      final data = await supabase
          .from('usuarios')
          .select('rol, nombre')
          .eq('id', user.id)
          .single();

      final prefs = await SharedPreferences.getInstance();
      // ✅ USA StorageKeys SIEMPRE
      await prefs.setString(StorageKeys.token, session.accessToken);
      await prefs.setString(StorageKeys.userId, user.id);
      await prefs.setString(StorageKeys.userRol, data['rol'] ?? 'cobrador');
      await prefs.setString(StorageKeys.userNombre, data['nombre'] ?? '');

      debugPrint('✅ Login OK con StorageKeys');
      debugPrint('   Token: ${session.accessToken.substring(0, 30)}...');
      debugPrint('   userId: ${user.id}');
      debugPrint('   rol: ${data['rol']}');
      debugPrint('   nombre: ${data['nombre']}');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Error de login: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.userId);
    await prefs.remove(StorageKeys.userRol);
    await prefs.remove(StorageKeys.userNombre);
    notifyListeners();
  }

  // ✅ Helpers estáticos para leer desde cualquier parte
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.token);
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.userId) ?? '';
  }

  static Future<String> getRol() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(StorageKeys.userRol) ?? 'cobrador').trim().toLowerCase();
  }

  static Future<String> getNombre() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(StorageKeys.userNombre) ?? 'Usuario').trim();
  }

  static Future<bool> esAdmin() async => (await getRol()) == 'admin';
}
