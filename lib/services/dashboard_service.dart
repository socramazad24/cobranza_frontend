// lib/services/dashboard_service.dart
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class DashboardService {
  /// Llama al endpoint optimizado del dashboard según el rol del usuario.
  /// El backend decide qué datos devolver.
  Future<Map<String, dynamic>> getDashboard({String? fecha}) async {
    final query = fecha != null ? '?fecha=$fecha' : '';
    final response = await ApiClient.get('${Constants.apiUrl}/api/dashboard/admin$query');

    if (response == null || response.statusCode != 200) {
      throw Exception('No se pudo cargar el dashboard admin');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDashboardCobrador({String? fecha}) async {
    final query = fecha != null ? '?fecha=$fecha' : '';
    final response = await ApiClient.get('${Constants.apiUrl}/api/dashboard/cobrador$query');

    if (response == null || response.statusCode != 200) {
      throw Exception('No se pudo cargar el dashboard del cobrador');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
