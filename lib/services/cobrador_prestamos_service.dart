import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class CobradorPrestamosService {
  Future<List<dynamic>> getPrestamosPorCobrador(String cobradorId) async {
    final response = await ApiClient.get(
      '${Constants.apiUrl}/api/loans/cobrador/$cobradorId',
    );

    if (response == null) return [];
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    return [];
  }
}