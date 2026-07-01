// lib/screens/reportes_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth_provider.dart';
import 'package:frontend_flutter/services/calendario_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_refresh_provider.dart';
import '../services/report_service.dart';
import '../widgets/calendario_pagos_widget.dart';
import 'detalle_prestamo_screen.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with AutomaticKeepAliveClientMixin {
  final ReportService reportService = ReportService();
  final CalendarioService _calendarioService = CalendarioService();

  Map<String, dynamic>? resumen;
  Map<String, dynamic>? resumenGastos;
  bool isLoading = false;
  bool esAdmin = false;

  // 🆕 Cuotas del día para cobradores
  CuotasDelDia? _cuotasDelDia;
  bool _isLoadingCuotas = false;

  RealtimeChannel? _channel;
  Timer? _debounce;
  int _lastDashboardTick = -1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await cargarDatos();
      _initRealtime();
    });
  }

  void _initRealtime() {
    final supabase = Supabase.instance.client;

    _channel = supabase.channel('dashboard-live')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'prestamos',
        callback: (_) => _scheduleReload(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'pagos',
        callback: (_) => _scheduleReload(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'pagos_programados',
        callback: (_) => _scheduleReload(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'gastos',
        callback: (_) => _scheduleReload(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'caja_diaria',
        callback: (_) => _scheduleReload(),
      )
      ..subscribe();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      await cargarDatos(silent: true);
    });
  }

  Future<void> cargarDatos({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => isLoading = true);

    try {
      esAdmin = await AuthProvider.esAdmin();

      // 🆕 Cargar cuotas del día en paralelo (solo para cobradores)
      if (!esAdmin) {
        _cargarCuotasDelDia();
      }

      if (esAdmin) {
        final results = await Future.wait([
          reportService.getResumen(),
          reportService.getResumenGastos(),
        ]);

        if (!mounted) return;
        setState(() {
          resumen = results[0];
          resumenGastos = results[1];
          isLoading = false;
        });
      } else {
        final data = await reportService.getResumenCobrador();
        if (!mounted) return;
        setState(() {
          resumen = data;
          resumenGastos = null;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando dashboard: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 🆕 Cargar las cuotas del día
  Future<void> _cargarCuotasDelDia() async {
    if (!mounted) return;
    setState(() => _isLoadingCuotas = true);

    try {
      final data = await _calendarioService.getCuotasDelDia();
      if (!mounted) return;
      setState(() {
        _cuotasDelDia = data;
        _isLoadingCuotas = false;
      });
    } catch (e) {
      debugPrint('Error cargando cuotas del día: $e');
      if (mounted) setState(() => _isLoadingCuotas = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tick = context.watch<AppRefreshProvider>().dashboardTick;
    if (_lastDashboardTick != tick) {
      _lastDashboardTick = tick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        cargarDatos(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading && resumen == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (resumen == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () => cargarDatos(),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => cargarDatos(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 🆕 SECCIÓN COBRADOR: Cuotas de hoy (lo primero que ve) ──
            if (!esAdmin) _buildSeccionCuotasHoy(),

            // ── SECCIÓN ADMIN: Dashboard normal ──
            if (esAdmin) _buildVistaAdmin() else _buildVistaCobrador(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🆕 SECCIÓN DE CUOTAS DEL DÍA
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSeccionCuotasHoy() {
    if (_isLoadingCuotas && _cuotasDelDia == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_cuotasDelDia == null) return const SizedBox.shrink();

    // Si NO tiene cuotas pendientes, mostrar tarjeta motivacional
    if (_cuotasDelDia!.cuotas.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.celebration, color: Colors.white, size: 40),
            const SizedBox(height: 8),
            const Text(
              '¡No hay cuotas para hoy!',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'No tienes clientes con pagos programados para ${_formatFechaCorta(_cuotasDelDia!.fecha)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return CuotasDelDiaWidget(
      cuotasDelDia: _cuotasDelDia!,
      isLoading: _isLoadingCuotas,
      onRefresh: _cargarCuotasDelDia,
      onCuotaTap: _irAPrestamo,
    );
  }

  String _formatFechaCorta(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  // ═══════════════════════════════════════════════════════════════
  // NAVEGAR AL PRÉSTAMO
  // ═══════════════════════════════════════════════════════════════
  Future<void> _irAPrestamo(CuotaProgramada cuota) async {
    try {
      // Necesitamos obtener los datos del préstamo
      // Lo más fácil es recargar y encontrarlo, o hacer una llamada directa
      final prestamos = await _calendarioService.getCalendarioPagos(cuota.prestamoId);
      // No podemos abrir el detalle sin el Map completo del préstamo
      // Mejor: abrir desde la lista de préstamos

      // Por ahora, mostramos un mensaje
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente: ${cuota.clienteNombre} - Cuota: \$${cuota.montoEsperado.toStringAsFixed(0)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Ver préstamos',
              textColor: Colors.white,
              onPressed: () {
                DefaultTabController.of(context).animateTo(2); // Ir a Préstamos
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navegando: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // VISTA COBRADOR (mejorada)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildVistaCobrador() {
    final totalPrestado = _safeDouble(resumen?['total_prestado'] ?? resumen?['totalprestado']);
    final totalPendiente = _safeDouble(resumen?['total_pendiente'] ?? resumen?['totalpendiente']);
    final totalRecaudadoHoy = _safeDouble(resumen?['total_recaudado_hoy'] ?? resumen?['totalrecaudadohoy']);
    final enMora = _safeInt(resumen?['cantidad_en_mora'] ?? resumen?['cantidadenmora']);
    final totalGastos = _safeDouble(resumen?['total_gastos_hoy'] ?? resumen?['totalgastoshoy']);
    final utilidad = totalRecaudadoHoy - totalGastos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── HEADER PERSONALIZADO ──
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola, ${_safeStr(resumen?['nombre'], defaultValue: 'Cobrador')}! 👋',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Aquí está tu día de hoy',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),

        // ── KPIs PERSONALES ──
        Row(
          children: [
            Expanded(
              child: _statCard('Mi cartera', '\$${_formatMoney(totalPrestado)}', Icons.account_balance_wallet, Colors.blue),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('Por cobrar', '\$${_formatMoney(totalPendiente)}', Icons.pending_actions, Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _statCard('Cobrado hoy', '\$${_formatMoney(totalRecaudadoHoy)}', Icons.payments, Colors.green),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard('En mora', '$enMora', Icons.warning, Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── TARJETA DE UTILIDAD ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: utilidad >= 0
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.red.shade400, Colors.red.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                utilidad >= 0 ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Utilidad del día',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('\$${_formatMoney(utilidad)}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VISTA ADMIN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildVistaAdmin() {
    final totalPrestado = _safeDouble(resumen?['total_general_prestado'] ?? resumen?['totalgeneralprestado']);
    final totalPendiente = _safeDouble(resumen?['total_general_pendiente'] ?? resumen?['totalgeneralpendiente']);
    final totalRecaudadoHoy = _safeDouble(resumen?['total_recaudado_hoy'] ?? resumen?['totalrecaudadohoy']);
    final totalGastosHoy = _safeDouble(resumenGastos?['total_gastos'] ?? resumen?['total_gastos_hoy']);
    final utilidadHoy = _safeDouble(resumen?['utilidad_hoy_estimada'] ?? resumen?['utilidad_hoy']) != 0
        ? _safeDouble(resumen?['utilidad_hoy_estimada'] ?? resumen?['utilidad_hoy'])
        : (totalRecaudadoHoy - totalGastosHoy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text('Dashboard Admin',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Wrap(
          runSpacing: 12,
          spacing: 12,
          children: [
            _statCard('Total prestado', '\$${_formatMoney(totalPrestado)}', Icons.account_balance_wallet, Colors.blue),
            _statCard('Saldo pendiente', '\$${_formatMoney(totalPendiente)}', Icons.pending_actions, Colors.orange),
            _statCard('Recaudado hoy', '\$${_formatMoney(totalRecaudadoHoy)}', Icons.payments, Colors.green),
            _statCard('Gastos hoy', '\$${_formatMoney(totalGastosHoy)}', Icons.money_off, Colors.red),
            _statCard(
              'Utilidad hoy',
              '\$${_formatMoney(utilidadHoy)}',
              Icons.account_balance,
              utilidadHoy >= 0 ? Colors.teal : Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCobradorList(),
      ],
    );
  }

  Widget _buildCobradorList() {
    final List<dynamic> porCobrador = resumen?['por_cobrador'] ?? [];
    if (porCobrador.isEmpty) {
      return const Text('No hay cobradores con datos.',
          style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Detalle por cobrador',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...porCobrador.map((c) {
          final nombre = _safeStr(c['nombre']);
          final prestamos = _safeInt(c['cantidad_prestamos'] ?? c['cantidadprestamos']);
          final recaudado = _safeDouble(c['total_recaudado_hoy'] ?? c['totalrecaudadohoy']);
          final pendiente = _safeDouble(c['total_pendiente'] ?? c['totalpendiente']);
          final enMora = _safeInt(c['cantidad_en_mora'] ?? c['cantidadenmora']);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('$prestamos préstamos • $enMora en mora'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${_formatMoney(recaudado)}',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('saldo: \$${_formatMoney(pendiente)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPONENTES AUXILIARES
  // ═══════════════════════════════════════════════════════════════
  Widget _statCard(String titulo, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(titulo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(valor,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  double _safeDouble(dynamic value, {double defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  int _safeInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  String _safeStr(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }
}
