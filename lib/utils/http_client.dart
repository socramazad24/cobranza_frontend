import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';

class ApiClient {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwttoken');
  }

  static Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final context = navigatorKey.currentContext;
    if (context == null) return;

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static Map<String, String> _headers(
    String? token, {
    bool json = true,
  }) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static void _mostrarSnackBar(String mensaje) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
      ),
    );
  }

  static Future<http.Response?> _manejarRespuesta(http.Response response) async {
    if (response.statusCode == 401) {
      _mostrarSnackBar('Sesión expirada. Inicia sesión nuevamente.');
      await _cerrarSesion();
      return null;
    }
    return response;
  }

  static Future<http.Response?> get(String url) async {
    final token = await _getToken();

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _headers(token, json: false),
      );

      return await _manejarRespuesta(response);
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  static Future<http.Response?> post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final token = await _getToken();

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body),
      );

      return await _manejarRespuesta(response);
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  static Future<http.Response?> put(
    String url,
    Map<String, dynamic> body,
  ) async {
    final token = await _getToken();

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body),
      );

      return await _manejarRespuesta(response);
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  static Future<http.Response?> patch(
    String url,
    Map<String, dynamic> body,
  ) async {
    final token = await _getToken();

    try {
      final response = await http.patch(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body),
      );

      return await _manejarRespuesta(response);
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  static Future<http.Response?> delete(String url) async {
    final token = await _getToken();

    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: _headers(token, json: false),
      );

      return await _manejarRespuesta(response);
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  static Future<http.Response?> deleteWithBody(
    String url,
    Map<String, dynamic> body,
  ) async {
    final token = await _getToken();

    try {
      final request = http.Request('DELETE', Uri.parse(url));
      request.headers.addAll(_headers(token));
      request.body = jsonEncode(body);

      final streamedResponse = await http.Client().send(request);
      final response = await http.Response.fromStream(streamedResponse);

      return await _manejarRespuesta(response);
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }
}