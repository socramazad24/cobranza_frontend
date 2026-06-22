// lib/services/admin_service.dart
import 'dart:convert';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class AdminService {
  Future<List> getAllUsers() async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/admin/users');

    if (response == null) return [];

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    }

    return [];
  }

  Future<bool> updateUser(String id, String nombre, String rol) async {
    final response = await ApiClient.put(
      '${Constants.apiUrl}/api/admin/users/$id',
      {
        'nombre': nombre,
        'rol': rol,
      },
    );

    return response?.statusCode == 200;
  }

  Future<bool> deleteUser(String id) async {
    final response = await ApiClient.delete(
      '${Constants.apiUrl}/api/admin/users/$id',
    );

    return response?.statusCode == 200;
  }
}