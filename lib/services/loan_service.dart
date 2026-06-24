// lib/services/loan_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class LoanService {
  Future<Map<String, dynamic>> createLoan({
    required String clienteNombre,
    required String clienteTelefono,
    required String clienteDireccion,
    required double montoPrestado,
    required double montoTotal,
    required int diasPlazo,
    required String cobradorId,
    required int rutaId,
    String modoInteres = 'manual',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwttoken');

    if (token == null || token.isEmpty) {
      return {
        'ok': false,
        'statusCode': 401,
        'error': 'Token no disponible',
      };
    }

    final url = Uri.parse('${Constants.apiUrl}/api/loans');

    final payload = {
      'clientenombre': clienteNombre.trim(),
      'clientetelefono': clienteTelefono.trim(),
      'clientedireccion': clienteDireccion.trim(),
      'montoprestado': montoPrestado,
      'montototal': montoTotal,
      'diasplazo': diasPlazo,
      'cobradorid': cobradorId,
      'rutaid': rutaId,
      'modointeres': modoInteres,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        body = {'raw': response.body};
      }

      if (response.statusCode == 201) {
        return {
          'ok': true,
          'statusCode': response.statusCode,
          'data': body,
        };
      } else {
        return {
          'ok': false,
          'statusCode': response.statusCode,
          'error': body['error'] ?? body['message'] ?? 'Error al crear préstamo',
          'data': body,
        };
      }
    } catch (e) {
      return {
        'ok': false,
        'statusCode': 500,
        'error': 'Excepción: $e',
      };
    }
  }
}