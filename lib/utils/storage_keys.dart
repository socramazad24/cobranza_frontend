// lib/utils/storage_keys.dart

/// Centraliza todas las keys de SharedPreferences para evitar inconsistencias.
class StorageKeys {
  StorageKeys._();

  // Auth
  static const String token = 'auth_token';
  static const String userId = 'user_id';
  static const String userRol = 'user_rol';
  static const String userNombre = 'user_nombre';
  static const String userEmail = 'user_email';

  // Preferencias
  static const String fechaSeleccionada = 'dashboard_fecha';
  static const String ultimaRutaCobrador = 'ultima_ruta_cobrador';
}
