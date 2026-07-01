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
      final user = response.user;

      if (session == null || user == null) return false;

      // Obtiene rol y nombre desde tabla usuarios
      final data = await Supabase.instance.client
          .from('usuarios')
          .select('rol, nombre')
          .eq('id', user.id)
          .single();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwttoken', session.accessToken);
      await prefs.setString('userrol', data['rol'] ?? 'cobrador');
      await prefs.setString('usernombre', data['nombre'] ?? '');
      await prefs.setString('userid', user.id);

      print('Login OK - rol: ${data['rol']} - token: ${session.accessToken.substring(0, 20)}...');
      return true;
    } catch (e) {
      print('Error login: $e');
      return false;
    }
  }

  // Solo verifica sesión activa de Supabase
  Future<bool> isLogged() async {
    return Supabase.instance.client.auth.currentSession != null;
  }
}
