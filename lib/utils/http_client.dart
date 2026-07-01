// lib/utils/http_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../screens/login_screen.dart';
import 'storage_keys.dart';

class ApiClient {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static const Duration _timeout = Duration(seconds: 10);

  static Future<String?> _getToken() async {
    // ✅ Lee de StorageKeys (no de 'jwt_token' ni 'jwttoken')
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.token);
  }

  static Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.token);
    await prefs.remove(StorageKeys.userId);
    await prefs.remove(StorageKeys.userRol);
    await prefs.remove(StorageKeys.userNombre);

    final context = navigatorKey.currentContext;
    if (context == null) return;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static Map<String, String> _headers(String? token, {bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static void _mostrarSnackBar(String mensaje, {Color color = Colors.red}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: color, duration: const Duration(seconds: 4)),
    );
  }

  static Future<bool> _hayInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  static Future<http.Response?> _request(
    Future<http.Response> Function() send,
    String method,
    String url,
  ) async {
    if (!await _hayInternet()) {
      _mostrarSnackBar('❌ Sin conexión a internet');
      debugPrint('[$method] Sin internet -> $url');
      return null;
    }
    try {
      final response = await send().timeout(_timeout);
      debugPrint('[$method] ${response.statusCode} $url');
      if (response.statusCode == 401) {
        _mostrarSnackBar('Sesión expirada');
        await _cerrarSesion();
        return null;
      }
      return response;
    } on TimeoutException {
      _mostrarSnackBar('⏱️ Tiempo agotado');
      debugPrint('[$method] TIMEOUT $url');
      return null;
    } on SocketException catch (e) {
      _mostrarSnackBar('❌ No se puede conectar al servidor');
      debugPrint('[$method] SOCKET ERROR $url: $e');
      return null;
    } catch (e) {
      _mostrarSnackBar('❌ Error: $e');
      debugPrint('[$method] ERROR $url: $e');
      return null;
    }
  }

  static Future<http.Response?> get(String url) async {
    final token = await _getToken();
    return _request(
      () => http.get(Uri.parse(url), headers: _headers(token, json: false)),
      'GET',
      url,
    );
  }

  static Future<http.Response?> post(String url, Map<String, dynamic> body) async {
    final token = await _getToken();
    return _request(
      () => http.post(Uri.parse(url), headers: _headers(token), body: jsonEncode(body)),
      'POST',
      url,
    );
  }

  static Future<http.Response?> put(String url, Map<String, dynamic> body) async {
    final token = await _getToken();
    return _request(
      () => http.put(Uri.parse(url), headers: _headers(token), body: jsonEncode(body)),
      'PUT',
      url,
    );
  }

  static Future<http.Response?> delete(String url) async {
    final token = await _getToken();
    return _request(
      () => http.delete(Uri.parse(url), headers: _headers(token, json: false)),
      'DELETE',
      url,
    );
  }

  static Future<http.Response?> deleteWithBody(String url, Map<String, dynamic> body) async {
    final token = await _getToken();
    return _request(
      () async {
        final request = http.Request('DELETE', Uri.parse(url));
        request.headers.addAll(_headers(token));
        request.body = jsonEncode(body);
        final streamedResponse = await http.Client().send(request);
        return await http.Response.fromStream(streamedResponse);
      },
      'DELETE',
      url,
    );
  }
}
