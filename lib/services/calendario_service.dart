// lib/services/calendario_service.dart
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class CuotaProgramada {
  final int? pagoProgramadoId;
  final int prestamoId;
  final int numeroPago;
  final DateTime fechaProgramada;
  final double montoEsperado;
  final String clienteNombre;
  final String clienteTelefono;
  final String rutaNombre;
  final String estadoPrestamo;
  final double saldoPendiente;

  CuotaProgramada({
    this.pagoProgramadoId,
    required this.prestamoId,
    required this.numeroPago,
    required this.fechaProgramada,
    required this.montoEsperado,
    required this.clienteNombre,
    required this.clienteTelefono,
    required this.rutaNombre,
    required this.estadoPrestamo,
    required this.saldoPendiente,
  });

  factory CuotaProgramada.fromJson(Map<String, dynamic> json) {
    return CuotaProgramada(
      pagoProgramadoId: _safeIntFromAny(json['pago_programado_id']),
      prestamoId: _safeIntFromAny(json['prestamo_id']),
      numeroPago: _safeIntFromAny(json['numero_pago']),
      fechaProgramada: _safeFechaParse(json['fecha_programada']),
      montoEsperado: _safeDoubleFromAny(json['monto_esperado']),
      clienteNombre: json['cliente_nombre']?.toString() ?? 'Sin nombre',
      clienteTelefono: json['cliente_telefono']?.toString() ?? '',
      rutaNombre: json['ruta_nombre']?.toString() ?? '',
      estadoPrestamo: json['estado_prestamo']?.toString() ?? 'activo',
      saldoPendiente: _safeDoubleFromAny(json['saldo_pendiente']),
    );
  }
}

class CuotasDelDia {
  final DateTime fecha;
  final int totalCuotasPendientes;
  final double totalEsperado;
  final double totalPagadoHoy;
  final List<CuotaProgramada> cuotas;

  CuotasDelDia({
    required this.fecha,
    required this.totalCuotasPendientes,
    required this.totalEsperado,
    required this.totalPagadoHoy,
    required this.cuotas,
  });

  factory CuotasDelDia.fromJson(Map<String, dynamic> json) {
    final resumen = json['resumen'] as Map<String, dynamic>? ?? {};
    return CuotasDelDia(
      fecha: _safeFechaParse(json['fecha']),
      totalCuotasPendientes: _safeIntFromAny(resumen['total_cuotas_pendientes']),
      totalEsperado: _safeDoubleFromAny(resumen['total_esperado']),
      totalPagadoHoy: _safeDoubleFromAny(resumen['total_pagado_hoy']),
      cuotas: ((json['cuotas'] as List?) ?? [])
          .map((c) => CuotaProgramada.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PagoDelDia {
  final int id;
  final double monto;
  final DateTime fecha;

  PagoDelDia({required this.id, required this.monto, required this.fecha});

  factory PagoDelDia.fromJson(Map<String, dynamic> json) {
    return PagoDelDia(
      id: _safeIntFromAny(json['id']),
      monto: _safeDoubleFromAny(json['monto']),
      fecha: _safeFechaParse(json['fecha']),
    );
  }
}

class PagosHoyPrestamo {
  final int prestamoId;
  final DateTime fecha;
  final double totalCobradoHoy;
  final int cantidadPagos;
  final List<PagoDelDia> pagos;

  PagosHoyPrestamo({
    required this.prestamoId,
    required this.fecha,
    required this.totalCobradoHoy,
    required this.cantidadPagos,
    required this.pagos,
  });

  factory PagosHoyPrestamo.fromJson(Map<String, dynamic> json) {
    return PagosHoyPrestamo(
      prestamoId: _safeIntFromAny(json['prestamo_id']),
      fecha: _safeFechaParse(json['fecha']),
      totalCobradoHoy: _safeDoubleFromAny(json['total_cobrado_hoy']),
      cantidadPagos: _safeIntFromAny(json['cantidad_pagos']),
      pagos: ((json['pagos'] as List?) ?? [])
          .map((p) => PagoDelDia.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CalendarioService {
  Future<CuotasDelDia> getCuotasDelDia({DateTime? fecha}) async {
    final fechaStr = fecha != null
        ? DateFormat('yyyy-MM-dd').format(fecha)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    final response = await ApiClient.get('${Constants.apiUrl}/api/dashboard/cuotas-hoy?fecha=$fechaStr');

    if (response == null || response.statusCode != 200) {
      throw Exception('Error al cargar cuotas del día');
    }

    return CuotasDelDia.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getCalendarioPagos(int prestamoId) async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/loans/$prestamoId/calendario');

    if (response == null || response.statusCode != 200) {
      throw Exception('Error al cargar calendario');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<PagosHoyPrestamo> getPagosHoyDePrestamo(int prestamoId) async {
    final response = await ApiClient.get('${Constants.apiUrl}/api/payments/today/$prestamoId');

    if (response == null || response.statusCode != 200) {
      throw Exception('Error al cargar pagos del día');
    }

    return PagosHoyPrestamo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

// ═══════════════════════════════════════════════════════════
//  HELPERS SEGUROS
// ═══════════════════════════════════════════════════════════
double _safeDoubleFromAny(dynamic value, {double defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int _safeIntFromAny(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

DateTime _safeFechaParse(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return DateTime.now();
  }
}
