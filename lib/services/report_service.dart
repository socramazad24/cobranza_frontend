import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class ReportService {
  Future<Map<String, dynamic>> getResumen({String? fecha}) async {
    final query = fecha != null ? '?fecha=$fecha' : '';
    final response =
        await ApiClient.get('${Constants.apiUrl}/api/reports/resumen$query');

    if (response == null || response.statusCode != 200) {
      throw Exception('No se pudo cargar el resumen general');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getResumenCobrador({String? fecha}) async {
    final query = fecha != null ? '?fecha=$fecha' : '';
    final response = await ApiClient.get(
      '${Constants.apiUrl}/api/reports/resumen-cobrador$query',
    );

    if (response == null || response.statusCode != 200) {
      throw Exception('No se pudo cargar el resumen del cobrador');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getResumenGastos({String? fecha}) async {
    final query = fecha != null ? '?fecha=$fecha' : '';
    final response = await ApiClient.get(
      '${Constants.apiUrl}/api/reports/resumen-gastos$query',
    );

    if (response == null || response.statusCode != 200) {
      throw Exception('No se pudo cargar el resumen de gastos');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>?> getUsuarioActual() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/auth/me');
    if (response != null && response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }
}