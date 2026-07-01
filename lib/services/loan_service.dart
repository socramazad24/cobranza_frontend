// lib/services/loan_service.dart
// lib/services/loan_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/storage_keys.dart';

class LoanService {
  /// Crea un préstamo con frecuencia de pago personalizable.
  Future<Map<String, dynamic>> createLoan({
    required String clienteNombre,
    required String clienteTelefono,
    required String clienteDireccion,
    required double montoPrestado,
    required double montoTotal,
    required int diasPlazo,
    required String cobradorId,
    required int rutaId,
    String frecuencia = 'diario',  // 🆕
    String modoInteres = 'manual',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageKeys.token);

    if (token == null || token.isEmpty) {
      return {'ok': false, 'statusCode': 401, 'error': 'Token no disponible'};
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
      'frecuencia': frecuencia,  // 🆕
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
        return {'ok': true, 'statusCode': response.statusCode, 'data': body};
      } else {
        return {
          'ok': false,
          'statusCode': response.statusCode,
          'error': body['error'] ?? body['message'] ?? 'Error al crear préstamo',
          'data': body,
        };
      }
    } catch (e) {
      return {'ok': false, 'statusCode': 500, 'error': 'Excepción: $e'};
    }
  }

  /// Obtiene el calendario de pagos programados de un préstamo
  Future<Map<String, dynamic>> getCalendarioPagos(int prestamoId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(StorageKeys.token);

    try {
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/api/loans/$prestamoId/calendario'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return {'ok': true, 'data': jsonDecode(response.body)};
      }
      return {'ok': false, 'error': 'Error ${response.statusCode}'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }
}
