import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_refresh_provider.dart';
import '../services/report_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with AutomaticKeepAliveClientMixin {
  final ReportService reportService = ReportService();

  Map<String, dynamic>? resumen;
  Map<String, dynamic>? resumenGastos;
  bool isLoading = false;
  bool esAdmin = false;

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
    if (!silent) {
      setState(() => isLoading = true);
    }

    try {
      await SharedPreferences.getInstance();
      esAdmin = await AuthProvider.esAdmin();


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
        padding: const EdgeInsets.all(16),
        child: esAdmin ? _buildVistaAdmin() : _buildVistaCobrador(),
      ),
    );
  }

  Widget _buildVistaAdmin() {
    final totalPrestado =
        (resumen?['total_general_prestado'] as num?)?.toDouble() ?? 0;
    final totalPendiente =
        (resumen?['total_general_pendiente'] as num?)?.toDouble() ?? 0;
    final totalRecaudadoHoy =
        (resumen?['total_recaudado_hoy'] as num?)?.toDouble() ?? 0;
    final totalGastosHoy =
        (resumenGastos?['total_gastos'] as num?)?.toDouble() ??
            (resumen?['total_gastos_hoy'] as num?)?.toDouble() ??
            0;
    final utilidadHoy =
        (resumen?['utilidad_hoy_estimada'] as num?)?.toDouble() ??
            (totalRecaudadoHoy - totalGastosHoy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Dashboard Admin',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          runSpacing: 12,
          spacing: 12,
          children: [
            _statCard('Total prestado', totalPrestado.toStringAsFixed(0), Colors.blue),
            _statCard('Saldo pendiente', totalPendiente.toStringAsFixed(0), Colors.orange),
            _statCard('Recaudado hoy', totalRecaudadoHoy.toStringAsFixed(0), Colors.green),
            _statCard('Gastos hoy', totalGastosHoy.toStringAsFixed(0), Colors.red),
            _statCard(
              'Utilidad hoy',
              utilidadHoy.toStringAsFixed(0),
              utilidadHoy >= 0 ? Colors.teal : Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildCobradorList(),
      ],
    );
  }

  Widget _buildVistaCobrador() {
    final totalPrestado = (resumen?['total_prestado'] as num?)?.toDouble() ?? 0;
    final totalPendiente = (resumen?['total_pendiente'] as num?)?.toDouble() ?? 0;
    final totalRecaudadoHoy =
        (resumen?['total_recaudado_hoy'] as num?)?.toDouble() ?? 0;
    final enMora = resumen?['cantidad_en_mora'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hola, ${resumen?['nombre'] ?? 'Cobrador'}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Wrap(
          runSpacing: 12,
          spacing: 12,
          children: [
            _statCard('Mi cartera', totalPrestado.toStringAsFixed(0), Colors.blue),
            _statCard('Por cobrar', totalPendiente.toStringAsFixed(0), Colors.orange),
            _statCard('Recaudado hoy', totalRecaudadoHoy.toStringAsFixed(0), Colors.green),
            _statCard('En mora', '$enMora', Colors.red),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String titulo, String valor, Color color) {
    return SizedBox(
      width: 170,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCobradorList() {
    final List<dynamic> porCobrador = resumen?['por_cobrador'] ?? [];
    if (porCobrador.isEmpty) {
      return const Text('No hay cobradores con datos.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalle por cobrador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...porCobrador.map((c) {
          return Card(
            child: ListTile(
              title: Text(c['nombre'] ?? 'Sin nombre'),
              subtitle: Text(
                'Préstamos: ${c['cantidad_prestamos'] ?? 0} • Recaudado hoy: ${((c['total_recaudado_hoy'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
              ),
              trailing: Text(
                ((c['total_pendiente'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }
}