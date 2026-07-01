// lib/screens/prestamos_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend_flutter/providers/auth_provider.dart';
import 'package:frontend_flutter/services/calendario_service.dart';
import 'package:frontend_flutter/widgets/aviso_cobro_hoy_widget.dart';
import 'package:frontend_flutter/widgets/calendario_pagos_widget.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';
import '../services/observacion_service.dart';
import '../services/cobrador_service.dart';
import '../services/excel_loan_service.dart';
import '../services/excel_export_service.dart';
import '../providers/app_refresh_provider.dart';
import 'nuevo_prestamo_screen.dart';

double _safeDouble(dynamic value, {double defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

int _safeInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

String _safeStr(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  return value.toString();
}

String _safeFecha(dynamic value, String formato, {String defaultValue = 'Fecha inválida'}) {
  if (value == null) return defaultValue;
  try {
    return DateFormat(formato).format(DateTime.parse(value.toString()));
  } catch (_) {
    return value.toString();
  }
}

class PrestamosScreen extends StatefulWidget {
  const PrestamosScreen({super.key});

  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> {
  List _prestamos = [];
  bool _isLoading = true;
  bool _isImporting = false;
  bool _isExporting = false;
  bool _esAdmin = false;

  final ExcelLoanService _excelLoanService = ExcelLoanService();
  final ExcelExportService _excelExportService = ExcelExportService();

  int _lastPrestamosTick = -1;

  @override
  void initState() {
    super.initState();
    _cargarRol();
    _cargarPrestamos();
  }

  Future<void> _cargarRol() async {
    final rol = await AuthProvider.getRol();
    if (mounted) setState(() => _esAdmin = rol == 'admin');
  }

  Future<void> _cargarPrestamos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final response = await ApiClient.get('${Constants.apiUrl}/api/payments/active');

    if (response != null && response.statusCode == 200 && mounted) {
      try {
        setState(() => _prestamos = jsonDecode(response.body) as List);
      } catch (e) {
        setState(() => _prestamos = []);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tick = context.watch<AppRefreshProvider>().prestamosTick;
    if (_lastPrestamosTick != tick) {
      _lastPrestamosTick = tick;
      WidgetsBinding.instance.addPostFrameCallback((_) => _cargarPrestamos());
    }
  }

  Future<void> _importarExcel() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    try {
      final file = await _excelLoanService.pickExcelFile();
      if (file == null) {
        setState(() => _isImporting = false);
        return;
      }
      final prestamos = await _excelLoanService.readLoansFromExcel(file);
      if (prestamos.isEmpty) {
        _showSnack('El archivo no contiene registros válidos', Colors.orange);
        setState(() => _isImporting = false);
        return;
      }
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('¿Importar préstamos?',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Se procesarán ${prestamos.length} registros desde el archivo Excel.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Importar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmar != true) {
        setState(() => _isImporting = false);
        return;
      }
      final result = await _excelLoanService.importarPrestamos(prestamos);
      if (!mounted) return;
      if (result['ok'] == true) {
        final data = result['data'] as Map<String, dynamic>;
        final creados = data['creados'] ?? 0;
        final errores = (data['errores'] as List?)?.length ?? 0;
        if (mounted) context.read<AppRefreshProvider>().refreshAll();
        await _cargarPrestamos();
        _showSnack('Importación completada. Creados: $creados, errores: $errores',
            errores == 0 ? Colors.green : Colors.orange);
      } else {
        _showSnack(result['error']?.toString() ?? 'Error importando Excel', Colors.red);
      }
    } catch (e) {
      _showSnack('Error importando archivo: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _exportarExcel() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      if (_prestamos.isEmpty) {
        _showSnack('No hay préstamos para exportar', Colors.orange);
        setState(() => _isExporting = false);
        return;
      }
      final file = await _excelExportService.exportPrestamos(_prestamos);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Archivo exportado: ${file.path.split(Platform.pathSeparator).last}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Abrir',
            textColor: Colors.white,
            onPressed: () => _excelExportService.openFile(file),
          ),
        ),
      );
    } catch (e) {
      _showSnack('Error exportando archivo: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showSnack(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBE9E7),
      appBar: AppBar(
        title: const Text('Préstamos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFBE9E7),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: _esAdmin
            ? [
                IconButton(
                  tooltip: 'Importar Excel',
                  icon: _isImporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file),
                  onPressed: _isImporting ? null : _importarExcel,
                ),
                IconButton(
                  tooltip: 'Exportar Excel',
                  icon: _isExporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  onPressed: _isExporting ? null : _exportarExcel,
                ),
                IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargarPrestamos),
              ]
            : [
                IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: _cargarPrestamos),
              ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final resultado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const NuevoPrestamoScreen()),
          );
          if (resultado == true && mounted) {
            context.read<AppRefreshProvider>().refreshAll();
            await _cargarPrestamos();
          }
        },
        backgroundColor: const Color(0xFFFFAB91),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Préstamo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarPrestamos,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _prestamos.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text('No hay préstamos activos.\nPresiona + para crear uno.',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _prestamos.length,
                    itemBuilder: (context, index) {
                      final p = _prestamos[index] as Map;
                      final cliente = (p['clientes'] as Map?) ?? {};
                      final ruta = cliente['rutas'] as Map?;
                      final cobrador = _safeStr(p['usuarios']?['nombre'] ?? p['cobradornombre'], defaultValue: 'Sin cobrador');
                      final saldo = _safeDouble(p['saldopendiente'] ?? p['saldo_pendiente']);
                      final cuota = _safeDouble(p['cuota_diaria'] ?? p['cuotadiaria']);
                      final frecuencia = _safeStr(p['frecuencia'], defaultValue: 'diario');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.orange[100], child: const Icon(Icons.person, color: Colors.orange)),
                          title: Text(_safeStr(cliente['nombre'], defaultValue: 'Sin cliente'),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Saldo: \$${saldo.toStringAsFixed(0)}'),
                              if (ruta != null)
                                Row(children: [
                                  const Icon(Icons.map, size: 12, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(_safeStr(ruta['nombre']), style: const TextStyle(fontSize: 12, color: Colors.blue)),
                                ]),
                              Row(children: [
                                const Icon(Icons.person_outline, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(cobrador, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ]),
                              if (frecuencia != 'diario')
                                Row(children: [
                                  const Icon(Icons.schedule, size: 12, color: Colors.purple),
                                  const SizedBox(width: 4),
                                  Text('Pago $frecuencia', style: const TextStyle(fontSize: 12, color: Colors.purple)),
                                ]),
                            ],
                          ),
                          trailing: Text('\$${cuota.toStringAsFixed(0)}/día',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          onTap: () async {
                            final prestamoCopia = Map<String, dynamic>.from(p);
                            final resultado = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(builder: (_) => DetallePrestamoScreen(prestamo: prestamoCopia)),
                            );
                            if (resultado == true && mounted) {
                              context.read<AppRefreshProvider>().refreshAll();
                              await _cargarPrestamos();
                            }
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DetallePrestamoScreen
// ═══════════════════════════════════════════════════════════════════

class DetallePrestamoScreen extends StatefulWidget {
  final Map prestamo;
  const DetallePrestamoScreen({super.key, required this.prestamo});

  @override
  State<DetallePrestamoScreen> createState() => _DetallePrestamoScreenState();
}

class _DetallePrestamoScreenState extends State<DetallePrestamoScreen> {
  List _historial = [];
  List _pagosProgramados = [];
  Map<String, dynamic>? _calendario;

  // 🆕 Datos del día
  PagosHoyPrestamo? _pagosHoy;
  bool _isLoadingHoy = false;
  bool _esAdmin = false;

  bool _isLoading = true;
  bool _isLoadingCalendario = false;
  bool _mostrarCalendario = true;
  bool _yaCargoInicial = false;
  final TextEditingController _montoController = TextEditingController();
  final CalendarioService _calendarioService = CalendarioService();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (_yaCargoInicial) return; // evita recargas múltiples
    _yaCargoInicial = true;

    final rol = await AuthProvider.getRol();
    if (mounted) setState(() => _esAdmin = rol == 'admin');

    // Carga paralela de TODO
    await Future.wait([
      _cargarHistorial(),
      _cargarCalendario(),
      _cargarPagosHoy(),
    ]);
  }

  Future<void> _cargarHistorial() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final response = await ApiClient.get('${Constants.apiUrl}/api/payments/history/${widget.prestamo['id']}');
    if (response != null && response.statusCode == 200 && mounted) {
      try {
        setState(() => _historial = jsonDecode(response.body) as List);
      } catch (_) {
        setState(() => _historial = []);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cargarCalendario() async {
    if (!mounted) return;
    setState(() => _isLoadingCalendario = true);
    try {
      final data = await _calendarioService.getCalendarioPagos(widget.prestamo['id']);
      if (!mounted) return;
      setState(() {
        _calendario = data;
        _pagosProgramados = (data['pagos_programados'] as List?) ?? [];
      });
    } catch (e) {
      debugPrint('Error cargando calendario: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCalendario = false);
    }
  }

  // 🆕 Carga los pagos hechos HOY a este préstamo
  Future<void> _cargarPagosHoy() async {
    if (!mounted) return;
    setState(() => _isLoadingHoy = true);
    try {
      final prestamoId = _safeInt(widget.prestamo['id']);
      if (prestamoId == 0) {
        setState(() {
          _pagosHoy = PagosHoyPrestamo(
            prestamoId: 0,
            fecha: DateTime.now(),
            totalCobradoHoy: 0,
            cantidadPagos: 0,
            pagos: [],
          );
          _isLoadingHoy = false;
        });
        return;
      }
      final data = await _calendarioService.getPagosHoyDePrestamo(prestamoId);
      if (!mounted) return;
      setState(() {
        _pagosHoy = data;
        _isLoadingHoy = false;
      });
    } catch (e) {
      debugPrint('Error cargando pagos de hoy: $e');
      if (mounted) {
        setState(() {
          _pagosHoy = PagosHoyPrestamo(
            prestamoId: _safeInt(widget.prestamo['id']),
            fecha: DateTime.now(),
            totalCobradoHoy: 0,
            cantidadPagos: 0,
            pagos: [],
          );
          _isLoadingHoy = false;
        });
      }
    }
  }

  void _toggleCalendario() {
    setState(() => _mostrarCalendario = !_mostrarCalendario);
  }

  Future<void> _registrarPago() async {
    final prestamoId = _safeInt(widget.prestamo['id']);
    final monto = _safeDouble(_montoController.text.trim());
    final saldoActual = _safeDouble(
      widget.prestamo['saldopendiente'] ?? widget.prestamo['saldo_pendiente'],
    );

    if (prestamoId == 0) {
      _mostrarSnack('No se encontró el ID del préstamo', Colors.red);
      return;
    }
    if (monto <= 0) {
      _mostrarSnack('Monto inválido', Colors.red);
      return;
    }
    if (monto > saldoActual) {
      _mostrarSnack(
        'El monto \$${monto.toStringAsFixed(0)} supera el saldo \$${saldoActual.toStringAsFixed(0)}',
        Colors.red,
      );
      return;
    }

    final cuotaSugerida =
        _safeDouble(_calendario?['prestamo']?['cuota_por_periodo']);
    final clienteNombre = _safeStr(
      widget.prestamo['clientes']?['nombre'],
      defaultValue: 'Sin nombre',
    );

    final yaCobradoHoy = _pagosHoy?.totalCobradoHoy ?? 0;
    final cantidadHoy = _pagosHoy?.cantidadPagos ?? 0;

    // Si ya cobró hoy, mostrar advertencia antes de la confirmación normal
    if (cantidadHoy > 0) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('⚠️ Ya cobraste hoy'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ya realizaste $cantidadHoy pago(s) hoy por un total de \$${yaCobradoHoy.toStringAsFixed(0)}.',
              ),
              const SizedBox(height: 8),
              const Text(
                '¿Estás seguro de registrar OTRO pago?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text(
                'Sí, registrar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (continuar != true) return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Confirmar pago?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: $clienteNombre'),
            Text('Monto: \$${monto.toStringAsFixed(0)}'),
            if (cuotaSugerida > 0 &&
                (monto - cuotaSugerida).abs() < 1)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '✅ Coincide con la cuota del día',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
            if (yaCobradoHoy > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ Ya cobraste \$${yaCobradoHoy.toStringAsFixed(0)} hoy a este cliente',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (monto >= saldoActual)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '🎉 Este pago completa el préstamo',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final body = {
      'prestamo_id': prestamoId,
      'monto_pagado': monto,
    };

    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/payments/pay',
      body,
    );

    if (!mounted) return;

    if (response != null && response.statusCode == 201) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final nuevoSaldo = _safeDouble(data['saldorestante']);
        final nuevoEstado =
            _safeStr(data['estado'], defaultValue: 'activo');

        setState(() {
          widget.prestamo['saldopendiente'] = nuevoSaldo;
          widget.prestamo['saldo_pendiente'] = nuevoSaldo;
          widget.prestamo['estado'] = nuevoEstado;
        });

        _montoController.clear();
        _yaCargoInicial = false;

        // 🆕 Forzar recarga de los pagos de hoy
        await _cargarPagosHoy();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Pago registrado. Total cobrado hoy: \$${_pagosHoy?.totalCobradoHoy.toStringAsFixed(0) ?? "0"}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        if (mounted) {
          context.read<AppRefreshProvider>().refreshAll();
        }

        _mostrarSnack(
          nuevoEstado == 'pagado'
              ? '🎉 ¡Préstamo completado!'
              : '✅ Pago registrado',
          Colors.green,
        );

        if (nuevoEstado == 'pagado') {
          Navigator.pop(context, true);
        }
      } catch (e) {
        _mostrarSnack(
          'Error procesando respuesta: $e',
          Colors.red,
        );
      }
    } else {
      String mensaje = 'Error al registrar pago';

      try {
        final data =
            jsonDecode(response?.body ?? '{}') as Map<String, dynamic>;
        mensaje = _safeStr(
          data['error'],
          defaultValue: mensaje,
        );
      } catch (_) {}

      _mostrarSnack(mensaje, Colors.red);
    }
  }

  void _mostrarSnack(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prestamo;
    final cliente = (p['clientes'] as Map?) ?? {};
    final ruta = cliente['rutas'] as Map?;
    final cobradorNombre = _safeStr(p['usuarios']?['nombre'] ?? p['cobradornombre'], defaultValue: 'Sin cobrador');
    final fechaInicio = _safeFecha(p['fecha_inicio'], 'dd MMM yyyy');
    final fechaFin = _safeFecha(p['fecha_fin'], 'dd MMM yyyy');
    final saldoPendiente = _safeDouble(p['saldopendiente'] ?? p['saldo_pendiente']);
    final montoPrestado = _safeDouble(p['monto_prestado'] ?? p['montoprestado']);
    final montoTotal = _safeDouble(p['monto_total'] ?? p['montototal']);
    final frecuencia = _safeStr(p['frecuencia'], defaultValue: 'diario');
    final estado = _safeStr(p['estado'], defaultValue: 'activo');
    final cuotaSugerida = _safeDouble(_calendario?['prestamo']?['cuota_por_periodo']);

    return Scaffold(
      backgroundColor: const Color(0xFFFBE9E7),
      appBar: AppBar(
        title: const Text('Detalle del Préstamo'),
        backgroundColor: const Color(0xFFFBE9E7),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(_mostrarCalendario ? Icons.list : Icons.calendar_today),
            tooltip: _mostrarCalendario ? 'Ver historial' : 'Ver calendario',
            onPressed: _toggleCalendario,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card del cliente
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          radius: 22,
                          child: Text(
                            (_safeStr(cliente['nombre']).isNotEmpty)
                                ? cliente['nombre'][0].toUpperCase()
                                : '?',
                            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_safeStr(cliente['nombre'], defaultValue: 'Sin cliente'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              if (cliente['telefono'] != null)
                                Text('📞 ${cliente['telefono']}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (ruta != null)
                      Row(children: [
                        const Icon(Icons.map, size: 14, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(_safeStr(ruta['nombre']), style: const TextStyle(color: Colors.blue, fontSize: 12)),
                        const SizedBox(width: 12),
                        const Icon(Icons.motorcycle, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(cobradorNombre, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniStat('Prestado', '\$${montoPrestado.toStringAsFixed(0)}', Colors.blue),
                          _miniStat('Total', '\$${montoTotal.toStringAsFixed(0)}', Colors.purple),
                          _miniStat('Saldo', '\$${saldoPendiente.toStringAsFixed(0)}', Colors.red),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getColorEstado(estado).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Estado: ${estado.toUpperCase()}',
                            style: TextStyle(color: _getColorEstado(estado), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Text('📅 $frecuencia',
                            style: TextStyle(color: Colors.purple.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.event, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('$fechaInicio → $fechaFin', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 🆕 AVISO DE COBRO HOY - LO MÁS IMPORTANTE
            if (!_isLoadingHoy && _pagosHoy != null)
              AvisoCobroHoyWidget(
                pagosHoy: _pagosHoy!,
                cuotaEsperada: cuotaSugerida > 0 ? cuotaSugerida : _safeDouble(widget.prestamo['cuota_diaria'] ?? widget.prestamo['cuotadiaria']),
              ),

            // Calendario o historial
            if (_mostrarCalendario) ...[
              if (_isLoadingCalendario)
                const Center(child: CircularProgressIndicator())
              else if (_calendario != null && _pagosProgramados.isNotEmpty)
                CalendarioPagosWidget(
                  totalPagos: _safeInt(_calendario!['prestamo']?['total_pagos']),
                  pagosRealizados: _safeInt(_calendario!['prestamo']?['pagos_realizados']),
                  cuotaPorPeriodo: _safeDouble(_calendario!['prestamo']?['cuota_por_periodo']),
                  montoTotal: _safeDouble(_calendario!['prestamo']?['monto_total']),
                  frecuencia: frecuencia,
                  pagosProgramados: _pagosProgramados.whereType<Map>().map<Map<String, dynamic>>((m) => m.cast<String, dynamic>()).toList(),
                  onPagoRealizado: _registrarPago,
                )
              else
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Column(children: [
                        Icon(Icons.calendar_today, size: 50, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No hay calendario disponible', style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text('Este préstamo fue creado antes del sistema de frecuencias',
                            style: TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ),
            ] else ...[
              const Text('Historial de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _historial.isEmpty
                      ? Card(child: const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin pagos aún', style: TextStyle(color: Colors.grey)))))
                      : Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _historial.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final pago = _historial[i] as Map;
                              return ListTile(
                                leading: const Icon(Icons.check_circle, color: Colors.green),
                                title: const Text('Abono registrado'),
                                subtitle: Text(_safeFecha(pago['fecha_pago'], 'dd MMM yyyy – hh:mm a'),
                                    style: const TextStyle(fontSize: 12)),
                                trailing: Text('\$${_safeDouble(pago['monto_pagado'] ?? pago['montopagado']).toStringAsFixed(0)}',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                              );
                            },
                          ),
                        ),
            ],
            const SizedBox(height: 16),

            // Registrar pago
            if (_mostrarCalendario)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Registrar Abono', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _montoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          hintText: 'Monto del abono',
                          helperText: 'Cuota del día: \$${cuotaSugerida.toStringAsFixed(0)} · Máx: \$${saldoPendiente.toStringAsFixed(0)}',
                          helperStyle: const TextStyle(color: Colors.grey),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _registrarPago,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81C784),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Registrar Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String valor, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      const SizedBox(height: 2),
      Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'mora':
        return Colors.red;
      case 'pagado':
        return Colors.green;
      case 'renovado':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }
}
