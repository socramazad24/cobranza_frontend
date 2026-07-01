// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend_flutter/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dashboard_service.dart';
import '../utils/storage_keys.dart';
import '../providers/app_refresh_provider.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _service = DashboardService();
  final fmt = NumberFormat('#,##0', 'es_CO');
  final dateFmt = DateFormat('dd MMM yyyy', 'es_CO');
  final dayFmt = DateFormat('EEE dd', 'es_CO');

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  bool _esAdmin = false;
  int _lastDashboardTick = -1;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _esAdmin = await AuthProvider.esAdmin();
      final data = _esAdmin
          ? await _service.getDashboard()
          : await _service.getDashboardCobrador();

      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tick = context.watch<AppRefreshProvider>().dashboardTick;
    if (_lastDashboardTick != tick) {
      _lastDashboardTick = tick;
      WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
    }
  }

  String _m(String key) => '\$${fmt.format(num.tryParse('${_data?['kpis']?[key] ?? 0}') ?? 0)}';

  String _i(String key) => '${_data?['kpis']?[key] ?? 0}';

  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════
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
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: _esAdmin ? _buildAdmin() : _buildCobrador(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  ADMIN
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAdmin() {
    final kpis = _data?['kpis'] as Map<String, dynamic>? ?? {};
    final porCobrador = (_data?['por_cobrador'] as List?) ?? [];
    final topCobradores = (_data?['top_cobradores'] as List?) ?? [];
    final topMorosos = (_data?['top_morosos'] as List?) ?? [];
    final observaciones = (_data?['observaciones_pendientes'] as List?) ?? [];
    final tendencia = (_data?['tendencia'] as List?) ?? [];
    final cajaGlobal = _data?['caja_global'] as Map<String, dynamic>?;
    final sinActividad = (_data?['cobradores_sin_actividad'] as List?) ?? [];

    final utilidad = num.tryParse('${kpis['utilidad_hoy'] ?? 0}')?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ── Header ──
        _header(titulo: 'Dashboard Admin', subtitulo: 'Vista general del día'),
        const SizedBox(height: 16),

        // ── KPIs grandes (los 5 más importantes) ──
        _kpiRow([
          _KpiData('Prestado', _m('total_prestado'), Icons.account_balance_wallet, Colors.blue),
          _KpiData('Cartera', _m('total_cartera'), Icons.pending_actions, Colors.orange),
          _KpiData('Recaudado hoy', _m('total_recaudado_hoy'), Icons.attach_money, Colors.green),
          _KpiData('Gastos hoy', _m('total_gastos_hoy'), Icons.money_off, Colors.red),
        ]),
        const SizedBox(height: 12),

        // ── Utilidad destacada ──
        _utilidadCard(utilidad),
        const SizedBox(height: 16),

        // ── Caja global del día ──
        if (cajaGlobal != null) _cajaGlobalCard(cajaGlobal),
        const SizedBox(height: 16),

        // ── Gráfica de tendencia 7 días ──
        if (tendencia.isNotEmpty) _graficaTendencia(tendencia),
        const SizedBox(height: 16),

        // ── Top cobradores del día ──
        if (topCobradores.isNotEmpty) ...[
          _sectionTitle('🏆 Top cobradores del día', Colors.amber),
          ...topCobradores.map((c) => _cobradorTile(c, highlight: true)),
          const SizedBox(height: 16),
        ],

        // ── Alerta: cobradores sin actividad ──
        if (sinActividad.isNotEmpty) ...[
          _alertaCard(
            titulo: '⚠️ ${sinActividad.length} cobradores sin actividad hoy',
            subtitulo: 'Cobradores con préstamos activos que aún no han cobrado',
            color: Colors.orange,
            onTap: () {
              // Navegar a la lista de cobradores si quieres
            },
          ),
          const SizedBox(height: 16),
        ],

        // ── Top morosos ──
        if (topMorosos.isNotEmpty) ...[
          _sectionTitle('🔥 Top morosos', Colors.red),
          ...topMorosos.map((m) => _morosoTile(m)),
          const SizedBox(height: 16),
        ],

        // ── Observaciones pendientes ──
        if (observaciones.isNotEmpty) ...[
          _sectionTitle('📋 Observaciones pendientes (${observaciones.length})', Colors.deepOrange),
          ...observaciones.map((o) => _observacionTile(o)),
          const SizedBox(height: 16),
        ],

        // ── Lista completa de cobradores ──
        if (porCobrador.isNotEmpty) ...[
          _sectionTitle('👥 Todos los cobradores', Colors.blue),
          ...porCobrador.map((c) => _cobradorTile(c)),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  COBRADOR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCobrador() {
    final kpis = _data?['kpis'] as Map<String, dynamic>? ?? {};
    final pagosHoy = (_data?['pagos_hoy_detalle'] as List?) ?? [];
    final proximosVencer = (_data?['proximos_a_vencer'] as List?) ?? [];
    final clientesMora = (_data?['clientes_en_mora'] as List?) ?? [];
    final tendencia = (_data?['tendencia'] as List?) ?? [];
    final rutas = (_data?['rutas'] as List?) ?? [];
    final miCaja = _data?['mi_caja'] as Map<String, dynamic>?;
    final nombre = _data?['usuario']?['nombre'] ?? 'Cobrador';

    final progreso = num.tryParse('${kpis['progreso_meta'] ?? 0}')?.toDouble() ?? 0;
    final metaDiaria = num.tryParse('${kpis['meta_diaria'] ?? 0}')?.toDouble() ?? 0;
    final recaudadoHoy = num.tryParse('${kpis['total_recaudado_hoy'] ?? 0}')?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ── Header personalizado ──
        _header(titulo: '¡Hola, $nombre! 👋', subtitulo: 'Aquí está tu día de hoy'),
        const SizedBox(height: 16),

        // ── Mi caja (si tiene) ──
        if (miCaja != null) _miCajaCard(miCaja),

        // ── Barra de progreso meta diaria ──
        _metaProgresoCard(recaudadoHoy, metaDiaria, progreso),
        const SizedBox(height: 16),

        // ── KPIs personales ──
        _kpiRow([
          _KpiData('Cartera', _m('mi_cartera'), Icons.account_balance_wallet, Colors.blue),
          _KpiData('Cobrado hoy', _m('total_recaudado_hoy'), Icons.payments, Colors.green),
          _KpiData('Pagos', _i('pagos_hoy'), Icons.receipt_long, Colors.teal),
          _KpiData('En mora', _i('prestamos_en_mora'), Icons.warning, Colors.red),
        ]),
        const SizedBox(height: 16),

        // ── Mis rutas ──
        if (rutas.isNotEmpty) _rutasCard(rutas),
        const SizedBox(height: 16),

        // ── Gráfica de mi tendencia ──
        if (tendencia.isNotEmpty) _graficaTendencia(tendencia, soloCobrado: true),
        const SizedBox(height: 16),

        // ── Pagos del día ──
        if (pagosHoy.isNotEmpty) ...[
          _sectionTitle('💰 Cobros del día (${pagosHoy.length})', Colors.green),
          ...pagosHoy.map((p) => _pagoHoyTile(p)),
          const SizedBox(height: 16),
        ],

        // ── Próximos a vencer ──
        if (proximosVencer.isNotEmpty) ...[
          _sectionTitle('⏰ Préstamos por vencer (próximos 3 días)', Colors.orange),
          ...proximosVencer.map((p) => _prestamoUrgenteTile(p)),
          const SizedBox(height: 16),
        ],

        // ── Clientes en mora ──
        if (clientesMora.isNotEmpty) ...[
          _sectionTitle('🔥 Clientes en mora (${clientesMora.length})', Colors.red),
          ...clientesMora.map((c) => _clienteMoraTile(c)),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  WIDGETS REUTILIZABLES
  // ═══════════════════════════════════════════════════════════════

  Widget _header({required String titulo, required String subtitulo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitulo, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    );
  }

  Widget _sectionTitle(String texto, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(texto, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _kpiRow(List<_KpiData> kpis) {
    return Row(
      children: [
        for (int i = 0; i < kpis.length; i++) ...[
          Expanded(child: _kpiCard(kpis[i])),
          if (i < kpis.length - 1) const SizedBox(width: 8),
        ]
      ],
    );
  }

  Widget _kpiCard(_KpiData k) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: k.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: k.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(k.icon, color: k.color, size: 22),
          const SizedBox(height: 6),
          Text(k.titulo, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            k.valor,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: k.color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _utilidadCard(double utilidad) {
    final positiva = utilidad >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positiva
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            positiva ? Icons.trending_up : Icons.trending_down,
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
                Text(
                  '\$${fmt.format(utilidad)}',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cajaGlobalCard(Map<String, dynamic> caja) {
    final pendiente = (caja['cajas_pendientes'] ?? 0) as int;
    final cerradas = (caja['cajas_cerradas'] ?? 0) as int;
    final saldo = num.tryParse('${caja['saldo_en_caja'] ?? 0}')?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              const Text('Caja global del día',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('Base entregada', '\$${fmt.format(num.tryParse('${caja['total_base_entregada'] ?? 0}') ?? 0)}', Colors.blue),
              _miniStat('Cobrado sistema', '\$${fmt.format(num.tryParse('${caja['total_cobrado'] ?? 0}') ?? 0)}', Colors.green),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('Entregado físico', '\$${fmt.format(num.tryParse('${caja['total_entregado'] ?? 0}') ?? 0)}', Colors.purple),
              _miniStat('Saldo en caja', '\$${fmt.format(saldo)}', saldo >= 0 ? Colors.amber : Colors.red),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text('$cerradas cerradas', style: TextStyle(color: Colors.green.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text('$pendiente abiertas', style: TextStyle(color: Colors.orange.shade800, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miCajaCard(Map<String, dynamic> caja) {
    final cerrada = caja['cerrada'] == true;
    final base = num.tryParse('${caja['base_entregada'] ?? 0}')?.toDouble() ?? 0;
    final cobrado = num.tryParse('${caja['total_cobrado'] ?? 0}')?.toDouble() ?? 0;
    final entregado = caja['total_entregado'];
    final pendiente = base + cobrado - ((entregado is num) ? entregado.toDouble() : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cerrada ? Colors.grey.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cerrada ? Colors.grey.shade300 : Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(cerrada ? Icons.lock : Icons.lock_open, color: cerrada ? Colors.grey : Colors.green),
              const SizedBox(width: 8),
              Text(
                cerrada ? 'Tu caja está cerrada' : 'Tu caja está abierta',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat('Base', '\$${fmt.format(base)}', Colors.blue),
              _miniStat('Cobrado', '\$${fmt.format(cobrado)}', Colors.green),
              _miniStat('Pendiente', '\$${fmt.format(pendiente)}', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaProgresoCard(double recaudado, double meta, double progreso) {
    final pct = progreso.clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade300, Colors.purple.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flag, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Tu meta diaria de cobros',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${fmt.format(recaudado)} / \$${fmt.format(meta)}',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pct.toStringAsFixed(0)}% completado',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _rutasCard(List rutas) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 6),
              const Text('Mis rutas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: rutas.map<Widget>((r) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  r['nombre']?.toString() ?? '',
                  style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _graficaTendencia(List datos, {bool soloCobrado = false}) {
    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < datos.length; i++) {
      final v = soloCobrado
          ? num.tryParse('${datos[i]['cobrado'] ?? 0}')?.toDouble() ?? 0
          : num.tryParse('${datos[i]['cobrado'] ?? 0}')?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
      if (v > maxY) maxY = v;
    }
    maxY = (maxY * 1.2).clamp(1000, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(soloCobrado ? '📈 Tus cobros (7 días)' : '📈 Tendencia últimos 7 días',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= datos.length) return const SizedBox.shrink();
                        final fecha = datos[i]['fecha']?.toString() ?? '';
                        final d = DateTime.tryParse(fecha);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            d != null ? dayFmt.format(d) : '',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          NumberFormat.compact().format(value),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (datos.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertaCard({required String titulo, required String subtitulo, required Color color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(subtitulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  Widget _cobradorTile(Map<String, dynamic> c, {bool highlight = false}) {
    final cobrado = num.tryParse('${c['total_cobrado_hoy'] ?? 0}')?.toDouble() ?? 0;
    final enMora = c['en_mora'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? Colors.amber.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? Colors.amber.shade200 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: highlight ? Colors.amber.shade200 : Colors.blue.shade100,
            child: Text(
              (c['nombre']?.toString().isNotEmpty ?? false) ? c['nombre'].toString()[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('${c['prestamos_activos'] ?? 0} préstamos', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (enMora > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)),
                        child: Text('$enMora en mora', style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                if ((c['rutas'] as List?)?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      (c['rutas'] as List).join(' • '),
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${fmt.format(cobrado)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cobrado > 0 ? Colors.green : Colors.grey)),
              const Text('cobrado hoy', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _morosoTile(Map<String, dynamic> m) {
    final saldo = num.tryParse('${m['saldo_pendiente'] ?? 0}')?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.red.shade100, child: const Icon(Icons.person, color: Colors.red)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['cliente_nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold)),
                if ((m['cliente_telefono'] ?? '').toString().isNotEmpty)
                  Text(m['cliente_telefono'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text('\$${fmt.format(saldo)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _observacionTile(Map<String, dynamic> o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.report_problem, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o['descripcion']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Text('Por: ${o['cobrador_nombre']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pagoHoyTile(Map<String, dynamic> p) {
    final monto = num.tryParse('${p['monto'] ?? 0}')?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(p['cliente_nombre'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Text('\$${fmt.format(monto)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  Widget _prestamoUrgenteTile(Map<String, dynamic> p) {
    final dias = _diasHasta(p['fecha_fin']?.toString());
    final saldo = num.tryParse('${p['saldo'] ?? 0}')?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dias <= 1 ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dias <= 1 ? Colors.red.shade300 : Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: dias <= 1 ? Colors.red : Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['cliente_nombre'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('Vence en $dias ${dias == 1 ? "día" : "días"}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text('\$${fmt.format(saldo)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _clienteMoraTile(Map<String, dynamic> c) {
    final saldo = num.tryParse('${c['saldo'] ?? 0}')?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Préstamo #${c['prestamo_id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Text('\$${fmt.format(saldo)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String valor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ],
    );
  }

  int _diasHasta(String? fechaStr) {
    if (fechaStr == null) return 99;
    try {
      final fecha = DateTime.parse(fechaStr);
      final ahora = DateTime.now();
      return fecha.difference(ahora).inDays;
    } catch (_) {
      return 99;
    }
  }
}

class _KpiData {
  final String titulo;
  final String valor;
  final IconData icon;
  final Color color;

  _KpiData(this.titulo, this.valor, this.icon, this.color);
}
