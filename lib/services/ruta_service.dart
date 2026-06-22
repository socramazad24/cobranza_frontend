// lib/services/ruta_service.dart
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class RutaService {
  Future<List> getRutas() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/rutas');

    if (response == null) return [];

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }

    return [];
  }

  Future<bool> createRuta(String nombre, String descripcion) async {
    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/rutas',
      {
        'nombre': nombre,
        'descripcion': descripcion,
      },
    );

    return response?.statusCode == 201;
  }

  Future<bool> deleteRuta(String id) async {
    final response = await ApiClient.delete(
      '${Constants.apiUrl}/api/rutas/$id',
    );

    return response?.statusCode == 200;
  }

  Future<bool> asignarRutas(String cobradorId, List rutaIds) async {
    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/rutas/asignar',
      {
        'cobrador_id': cobradorId,
        'ruta_ids': rutaIds,
      },
    );

    return response?.statusCode == 200;
  }

  Future<List> getRutasCobrador(String cobradorId) async {
    final response = await ApiClient.get(
      '${Constants.apiUrl}/api/rutas/cobrador/$cobradorId',
    );

    if (response == null) return [];

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }

    return [];
  }

  Future<Map<String, dynamic>> getResumenRuta(String id) async {
    final response = await ApiClient.get(
      '${Constants.apiUrl}/api/rutas/$id/resumen',
    );

    if (response == null) {
      throw Exception('No hubo respuesta del servidor');
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Error ${response.statusCode}: ${response.body}');
  }
}