// lib/services/loan_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class LoanService {
  Future<bool> createLoan(String clienteNombre, double monto, int diasPlazo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final url = Uri.parse('${Constants.apiUrl}/api/loans');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Enviamos el token para seguridad
        },
        body: jsonEncode({
          'cliente_nombre': clienteNombre,
          'monto_prestado': monto,
          'dias_plazo': diasPlazo,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        print('Error al crear préstamo: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Excepción: $e');
      return false;
    }
  }
}