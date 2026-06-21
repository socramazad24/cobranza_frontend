import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class ApiService {
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    return token;
  }

  // Ejemplo: Crear Préstamo llamando a Node.js
  Future<bool> createLoan(int clienteId, double monto, int dias) async {
    final token = await _getToken();
    final url = Uri.parse('${Constants.apiUrl}/api/loans');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Se envía el token JWT para el middleware
        },
        body: jsonEncode({
          'cliente_id': clienteId,
          'monto_prestado': monto,
          'dias_plazo': dias,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      }
    } catch (e) {
      print('Error en API: $e');
    }
    return false;
  }
}