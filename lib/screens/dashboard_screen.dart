import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/report_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReportService _reportService = ReportService();
  final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  Map<String, dynamic>? _resumen;
  bool _isLoading = true;
  bool _esAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDashboard();
  }

  Future<void> _cargarDashboard() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userData = await _reportService.getUsuarioActual();
      _esAdmin = (userData?['rol'] ?? 'cobrador') == 'admin';

      final data = _esAdmin
          ? await _reportService.getResumen()
          : await _reportService.getResumenCobrador();

      if (!mounted) return;
      setState(() {
        _resumen = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error cargando datos: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _cargarDashboard, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: _esAdmin ? _buildAdmin() : _buildCobrador(),
      ),
    );
  }

  Widget _buildCobrador() {
    final totalPrestado = _numFrom(['total_prestado', 'totalprestado']);
    final totalPendiente = _numFrom(['total_pendiente', 'totalpendiente']);
    final recaudadoHoy = _numFrom(['total_recaudado_hoy', 'totalrecaudadohoy']);
    final enMora = _resumen?['cantidad_en_mora'] ?? _resumen?['cantidadenmora'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hola, ${_resumen?['nombre'] ?? 'Cobrador'}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _statCard('Mi cartera', currency.format(totalPrestado), Colors.blue, Icons.account_balance_wallet),
            _statCard('Por cobrar', currency.format(totalPendiente), Colors.orange, Icons.pending_actions),
            _statCard('Recaudado hoy', currency.format(recaudadoHoy), Colors.green, Icons.attach_money),
            _statCard('En mora', '$enMora', Colors.red, Icons.warning_amber_rounded),
          ],
        ),
      ],
    );
  }

  Widget _buildAdmin() {
    final totalPrestado = _numFrom(['total_general_prestado', 'totalgeneralprestado']);
    final totalPendiente = _numFrom(['total_general_pendiente', 'totalgeneralpendiente']);
    final recaudadoHoy = _numFrom(['total_recaudado_hoy', 'totalrecaudadohoy']);
    final gastosHoy = _numFrom(['total_gastos_hoy', 'totalgastoshoy']);
    final porCobrador = (_resumen?['por_cobrador'] ?? _resumen?['porcobrador'] ?? []) as List<dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Dashboard Admin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _statCard('Total prestado', currency.format(totalPrestado), Colors.blue, Icons.account_balance_wallet),
            _statCard('Saldo pendiente', currency.format(totalPendiente), Colors.orange, Icons.pending_actions),
            _statCard('Recaudado hoy', currency.format(recaudadoHoy), Colors.green, Icons.attach_money),
            _statCard('Gastos hoy', currency.format(gastosHoy), Colors.red, Icons.money_off),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Detalle por cobrador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (porCobrador.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No hay cobradores con préstamos activos', style: TextStyle(color: Colors.grey))),
          )
        else
          ...porCobrador.map((c) {
            final pend = (c['total_pendiente'] ?? c['totalpendiente'] ?? 0) as num;
            final rec = (c['total_recaudado_hoy'] ?? c['totalrecaudadohoy'] ?? 0) as num;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(c['nombre'] ?? 'Sin nombre'),
                subtitle: Text('Recaudado hoy: ${currency.format(rec)}'),
                trailing: Text(currency.format(pend), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          }),
      ],
    );
  }

  num _numFrom(List<String> keys) {
    for (final k in keys) {
      final v = _resumen?[k];
      if (v != null) return num.tryParse(v.toString()) ?? 0;
    }
    return 0;
  }

  Widget _statCard(String titulo, String valor, Color color, IconData icon) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(titulo, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}