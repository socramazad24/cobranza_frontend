// lib/services/observacion_service.dart
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class ObservacionService {
  Future<bool> createObservacion(
    String tipo,
    int referenciaId,
    String descripcion,
  ) async {
    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/observaciones',
      {
        'tipo':          tipo,
        'referencia_id': referenciaId,
        'descripcion':   descripcion,
      },
    );
    return response?.statusCode == 201;
  }

  Future<List<dynamic>> getObservaciones({bool? resuelta}) async {
    final url = resuelta != null
        ? '${Constants.apiUrl}/api/observaciones?resuelta=$resuelta'
        : '${Constants.apiUrl}/api/observaciones';

    final response = await ApiClient.get(url);
    if (response == null) return [];
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<bool> resolverObservacion(int id) async {
    final response = await ApiClient.put(
      '${Constants.apiUrl}/api/observaciones/$id/resolver',
      {},
    );
    return response?.statusCode == 200;
  }
}