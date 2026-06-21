// lib/services/cobrador_service.dart
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class CobradorService {
  Future<List<dynamic>> getCobradores() async {
    final response =
        await ApiClient.get('${Constants.apiUrl}/api/auth/cobradores');
    if (response == null) return [];
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getRutas() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/rutas');
    if (response == null) return [];
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<bool> createCobrador(
    String nombre,
    String email,
    String password,
    List<int> rutasIds,
  ) async {
    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/auth/create-cobrador',
      {
        'nombre':    nombre,
        'email':     email,
        'password':  password,
        'rutas_ids': rutasIds,
      },
    );
    return response?.statusCode == 201;
  }

  Future<List<dynamic>> getRutasDeCobrador(String cobradorId) async {
    final response = await ApiClient.get(
        '${Constants.apiUrl}/api/rutas/cobrador/$cobradorId');
    if (response == null) return [];
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }
}