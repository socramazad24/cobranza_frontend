class Constants {
  // Configuración de Supabase
  static const String supabaseUrl = 'https://lruuxojvaofuhmngmmfe.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxydXV4b2p2YW9mdWhtbmdtbWZlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3OTIxNTMsImV4cCI6MjA5MDM2ODE1M30.aj_yn0jPEKvmQZqXWe5CWcRRoH1mi8Z3HR_z6xJ2mEQ';

  // ✅ Como corres con flutter run por USB:
  // 1. Ejecuta: adb reverse tcp:3000 tcp:3000
  // 2. La app en el celular usará localhost:3000 que apunta a tu PC
  static const String apiUrl = 'http://localhost:3000';

  // Si NO usas adb reverse, usa tu IP local (ejecuta ipconfig para verla):
  // static const String apiUrl = 'http://192.168.1.35:3000';

  // Nube (producción):
  // static const String apiUrl = 'https://cobranza-production-39dc.up.railway.app';
}
