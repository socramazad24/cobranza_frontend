// lib/services/client_service.dart
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class ClientService {
  Future<List<dynamic>> getClientes({String? cobradorId}) async {
    final url = cobradorId != null
        ? '${Constants.apiUrl}/api/clients?cobrador_id=$cobradorId'
        : '${Constants.apiUrl}/api/clients';

    final res = await ApiClient.get(url);
    if (res != null && res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Error ${res?.statusCode}: ${res?.body}');
  }

  Future<List<dynamic>> getCobradores() async {
    final res = await ApiClient.get('${Constants.apiUrl}/api/clients/cobradores');
    if (res != null && res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Error ${res?.statusCode}: ${res?.body}');
  }
}