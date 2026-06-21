// lib/screens/reportes_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/report_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with AutomaticKeepAliveClientMixin {

  final ReportService _reportService = ReportService();

  Map<String, dynamic>? _resumen;
  Map<String, dynamic>? _resumenGastos;
  bool _isLoading   = false;
  bool _esAdmin     = false;
  bool _dataCargada = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataCargada) {
      _dataCargada = true;
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId   = supabase.auth.currentUser?.id;

      String rol;

      if (userId != null) {
        final userData = await supabase
            .from('usuarios')
            .select('rol')
            .eq('id', userId)
            .single();

        rol = userData['rol'] ?? 'cobrador';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_rol', rol);
        await prefs.setString(
            'jwt_token', supabase.auth.currentSession?.accessToken ?? '');
      } else {
        final prefs = await SharedPreferences.getInstance();
        rol = prefs.getString('user_rol') ?? 'cobrador';
      }

      _esAdmin = rol == 'admin';

      if (_esAdmin) {
        final results = await Future.wait([
          _reportService.getResumen(),
          _reportService.getResumenGastos(),
        ]);
        if (!mounted) return;
        setState(() {
          _resumen       = results[0];
          _resumenGastos = results[1];
          _isLoading     = false;
        });
      } else {
        final data = await _reportService.getResumenCobrador();
        if (!mounted) return;
        setState(() {
          _resumen   = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading   = false;
        _dataCargada = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando reportes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _recargar() async {
    setState(() {
      _dataCargada   = false;
      _resumen       = null;
      _resumenGastos = null;
    });
    await _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_resumen == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Error cargando datos', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _recargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFE1F5FE),
      child: RefreshIndicator(
        onRefresh: _recargar,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _esAdmin
                ? _buildVistaAdmin()
                : _buildVistaCobrador(),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // VISTA ADMIN
  // ─────────────────────────────────────────
  List<Widget> _buildVistaAdmin() {
    final totalGastos    = (_resumenGastos?['total_gastos']  as num?)?.toDouble() ?? 0;
    final cantidadGastos = _resumenGastos?['cantidad_gastos'] ?? 0;
    final totalPrestado  = (_resumen!['total_general_prestado']  as num?)?.toDouble() ?? 0;
    final totalPendiente = (_resumen!['total_general_pendiente'] as num?)?.toDouble() ?? 0;
    final utilidad       = totalPendiente - totalGastos;

    return [
      const Text('Dashboard Admin',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Vista general del negocio',
          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      const SizedBox(height: 16),

      Row(children: [
        Expanded(child: _buildStatCard(
          'Total Prestado', '\$${totalPrestado.toStringAsFixed(0)}',
          Colors.blue[100]!, Icons.monetization_on, Colors.blue,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          'Saldo Pendiente', '\$${totalPendiente.toStringAsFixed(0)}',
          Colors.orange[100]!, Icons.hourglass_bottom, Colors.orange,
        )),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: _buildStatCard(
          'Gastos del Mes', '\$${totalGastos.toStringAsFixed(0)}',
          Colors.red[100]!, Icons.receipt_long, Colors.red,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          'Utilidad Est.', '\$${utilidad.toStringAsFixed(0)}',
          utilidad >= 0 ? Colors.green[100]! : Colors.red[200]!,
          Icons.trending_up,
          utilidad >= 0 ? Colors.green : Colors.red,
        )),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: _buildStatCard(
          'Préstamos Activos',
          '${_resumen!['cantidad_prestamos_activos'] ?? 0}',
          Colors.purple[100]!, Icons.people, Colors.purple,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          'Gastos Registrados', '$cantidadGastos',
          Colors.teal[100]!, Icons.list_alt, Colors.teal,
        )),
      ]),
      const SizedBox(height: 24),

      const Text('Distribución por Cobrador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(height: 200, child: _buildDonutChart()),
        ),
      ),
      const SizedBox(height: 24),

      if (_resumenGastos?['por_tipo'] != null) ...[
        const Text('Gastos por Tipo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildGastosPorTipo(),
        const SizedBox(height: 24),
      ],

      const Text('Detalle por Cobrador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      ..._buildCobradorList(),
    ];
  }

  // ─────────────────────────────────────────
  // VISTA COBRADOR
  // ─────────────────────────────────────────
  List<Widget> _buildVistaCobrador() {
    final totalPrestado    = (_resumen!['total_prestado']  as num?)?.toDouble() ?? 0;
    final totalPendiente   = (_resumen!['total_pendiente'] as num?)?.toDouble() ?? 0;
    final totalRecaudado   = (_resumen!['total_recaudado'] as num?)?.toDouble() ?? 0;
    final prestamosActivos = _resumen!['cantidad_prestamos_activos'] ?? 0;
    final enMora           = _resumen!['cantidad_en_mora']           ?? 0;
    final nombre           = _resumen!['nombre']                     ?? 'Cobrador';

    return [
      Text('Hola, $nombre 👋',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Tu resumen de hoy',
          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      const SizedBox(height: 16),

      Row(children: [
        Expanded(child: _buildStatCard(
          'Mi Cartera', '\$${totalPrestado.toStringAsFixed(0)}',
          Colors.blue[100]!, Icons.account_balance_wallet, Colors.blue,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          'Por Cobrar', '\$${totalPendiente.toStringAsFixed(0)}',
          Colors.orange[100]!, Icons.pending_actions, Colors.orange,
        )),
      ]),
      const SizedBox(height: 12),

      Row(children: [
        Expanded(child: _buildStatCard(
          'Recaudado', '\$${totalRecaudado.toStringAsFixed(0)}',
          Colors.green[100]!, Icons.check_circle, Colors.green,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(
          'En Mora', '$enMora clientes',
          enMora > 0 ? Colors.red[100]! : Colors.grey[200]!,
          Icons.warning_amber,
          enMora > 0 ? Colors.red : Colors.grey,
        )),
      ]),
      const SizedBox(height: 12),

      _buildStatCard(
        'Préstamos Activos', '$prestamosActivos',
        Colors.purple[100]!, Icons.people, Colors.purple,
      ),
      const SizedBox(height: 24),

      const Text('Progreso de Recaudo',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recaudado: \$${totalRecaudado.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Meta: \$${totalPrestado.toStringAsFixed(0)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: totalPrestado > 0
                      ? (totalRecaudado / totalPrestado).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 14,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                totalPrestado > 0
                    ? '${((totalRecaudado / totalPrestado) * 100).toStringAsFixed(1)}% completado'
                    : 'Sin préstamos activos',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // ─────────────────────────────────────────
  // WIDGETS REUTILIZABLES
  // ─────────────────────────────────────────
  Widget _buildStatCard(String titulo, String valor, Color color,
      IconData icono, Color iconColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icono, color: iconColor, size: 26),
            const SizedBox(height: 6),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconColor),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart() {
    final List<Color> colores = [
      Colors.blue, Colors.orange, Colors.green,
      Colors.purple, Colors.red, Colors.teal,
    ];
    final List<dynamic> porCobrador = _resumen!['por_cobrador'] ?? [];

    final validos = porCobrador
        .where((c) => ((c['total_prestado'] as num?)?.toDouble() ?? 0) > 0)
        .toList();

    if (validos.isEmpty) {
      return const Center(child: Text('Sin datos para el gráfico'));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 3,
        centerSpaceRadius: 40,
        sections: validos.asMap().entries.map((entry) {
          final i        = entry.key;
          final cobrador = entry.value;
          final total    = (cobrador['total_prestado'] as num?)?.toDouble() ?? 0;
          final nombre   = cobrador['nombre']?.toString() ?? 'N/A';
          return PieChartSectionData(
            color: colores[i % colores.length],
            value: total,
            title: nombre.split(' ')[0],
            radius: 50,
            titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGastosPorTipo() {
    final List<dynamic> porTipo = _resumenGastos!['por_tipo'] ?? [];
    final List<Color> colores = [
      Colors.red, Colors.orange, Colors.purple,
      Colors.teal, Colors.brown,
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: porTipo.asMap().entries.map((entry) {
            final i     = entry.key;
            final tipo  = entry.value;
            final monto = (tipo['total'] as num?)?.toDouble() ?? 0;
            final label = tipo['tipo_gasto']?.toString() ?? 'Sin tipo';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colores[i % colores.length],
                    child: Text(
                      label.isNotEmpty ? label[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label)),
                  Text('\$${monto.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colores[i % colores.length])),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Widget> _buildCobradorList() {
    final List<Color> colores = [
      Colors.blue, Colors.orange, Colors.green,
      Colors.purple, Colors.red,
    ];
    final List<dynamic> porCobrador = _resumen!['por_cobrador'] ?? [];

    return porCobrador.asMap().entries.map((entry) {
      final i        = entry.key;
      final cobrador = entry.value;
      final nombre   = cobrador['nombre']?.toString()                   ?? 'Sin nombre';
      final cantidad = cobrador['cantidad_prestamos']                    ?? 0;
      final prestado = (cobrador['total_prestado'] as num?)?.toDouble() ?? 0;

      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: colores[i % colores.length],
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(nombre,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('$cantidad préstamos activos'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${prestado.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green)),
              const Text('prestado',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );
    }).toList();
  }
}