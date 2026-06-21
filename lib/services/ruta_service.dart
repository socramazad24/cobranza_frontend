// lib/services/ruta_service.dart
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class RutaService {
  // Obtener todas las rutas
  Future<List<dynamic>> getRutas() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/rutas');
    if (response == null) return [];
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // Crear ruta
  Future<bool> createRuta(String nombre, String descripcion) async {
    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/rutas',
      {'nombre': nombre, 'descripcion': descripcion},
    );
    return response?.statusCode == 201;
  }

  // Eliminar ruta
  Future<bool> deleteRuta(int id) async {
    final response =
        await ApiClient.delete('${Constants.apiUrl}/api/rutas/$id');
    return response?.statusCode == 200;
  }

  // Asignar rutas a cobrador
  Future<bool> asignarRutas(String cobradorId, List<int> rutaIds) async {
    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/rutas/asignar',
      {'cobrador_id': cobradorId, 'ruta_ids': rutaIds},
    );
    return response?.statusCode == 200;
  }

  // Obtener rutas de un cobrador
  Future<List<dynamic>> getRutasCobrador(String cobradorId) async {
    final response = await ApiClient.get(
        '${Constants.apiUrl}/api/rutas/cobrador/$cobradorId');
    if (response == null) return [];
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }
}