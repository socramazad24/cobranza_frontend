// lib/services/expense_service.dart
import 'dart:convert';
import 'dart:io';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class ExpenseService {
  Future<String?> uploadComprobante(File imagen) async {
    final bytes    = await imagen.readAsBytes();
    final base64   = base64Encode(bytes);
    final fileName = imagen.path.split('/').last;
    final mimeType = fileName.endsWith('.png') ? 'image/png' : 'image/jpeg';

    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/expenses/upload',
      {
        'fileName':   fileName,
        'fileBase64': base64,
        'mimeType':   mimeType,
      },
    );
    if (response == null) return null;
    if (response.statusCode == 200) return jsonDecode(response.body)['url'];
    return null;
  }

  Future<bool> createExpense(
    String tipoGasto,
    double valor,
    String? cobradorId,
    String? comprobanteUrl,
  ) async {
    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/expenses',
      {
        'tipo_gasto':      tipoGasto,
        'valor':           valor,
        'cobrador_id':     cobradorId,
        'comprobante_url': comprobanteUrl,
      },
    );
    return response?.statusCode == 201;
  }

  Future<List<dynamic>> getExpenses() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/expenses');
    if (response == null) return [];
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }
}