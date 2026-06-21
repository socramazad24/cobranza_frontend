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
    return prefs.getString('jwt_token');
  }

  static Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  static Map<String, String> _headers(String? token,
      {bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static void _mostrarSnackBar(String mensaje) {
    navigatorKey.currentState?.context != null
        ? ScaffoldMessenger.of(navigatorKey.currentState!.context)
            .showSnackBar(SnackBar(
              content: Text(mensaje),
              backgroundColor: Colors.red,
            ))
        : null;
  }

  // ── GET ──────────────────────────────────────
  static Future<http.Response?> get(String url) async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _headers(token, json: false),
      );
      if (response.statusCode == 401) {
        _mostrarSnackBar('Sesión expirada. Inicia sesión nuevamente.');
        await _cerrarSesion();
        return null;
      }
      return response;
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  // ── POST ─────────────────────────────────────
  static Future<http.Response?> post(String url,
      Map<String, dynamic> body) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (response.statusCode == 401) {
        _mostrarSnackBar('Sesión expirada. Inicia sesión nuevamente.');
        await _cerrarSesion();
        return null;
      }
      return response;
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  // ── PUT ──────────────────────────────────────
  static Future<http.Response?> put(String url,
      Map<String, dynamic> body) async {
    final token = await _getToken();
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      if (response.statusCode == 401) {
        _mostrarSnackBar('Sesión expirada. Inicia sesión nuevamente.');
        await _cerrarSesion();
        return null;
      }
      return response;
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  // ── DELETE ───────────────────────────────────
  static Future<http.Response?> delete(String url) async {
    final token = await _getToken();
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: _headers(token, json: false),
      );
      if (response.statusCode == 401) {
        _mostrarSnackBar('Sesión expirada. Inicia sesión nuevamente.');
        await _cerrarSesion();
        return null;
      }
      return response;
    } catch (e) {
      _mostrarSnackBar('❌ Sin conexión al servidor');
      return null;
    }
  }

  static Future<http.Response?> deleteWithBody(String url, Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final request = http.Request('DELETE', Uri.parse(url));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.body = jsonEncode(body);
      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      return null;
    }
  }
}