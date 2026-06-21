// lib/services/report_service.dart
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class ReportService {
  Future<Map<String, dynamic>?> getResumen() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/reports/resumen');
    print('📊 getResumen status: ${response?.statusCode}');
    print('📊 getResumen body: ${response?.body}');
    if (response == null) return null;
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<Map<String, dynamic>?> getResumenCobrador() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/reports/resumen-cobrador');
    print('📊 getResumenCobrador status: ${response?.statusCode}');
    print('📊 getResumenCobrador body: ${response?.body}');
    if (response == null) return null;
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }

  Future<Map<String, dynamic>?> getResumenGastos() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/reports/gastos-resumen');
    print('📊 getResumenGastos status: ${response?.statusCode}');
    print('📊 getResumenGastos body: ${response?.body}');
    if (response == null) return null;
    if (response.statusCode == 200) return jsonDecode(response.body);
    return null;
  }
}