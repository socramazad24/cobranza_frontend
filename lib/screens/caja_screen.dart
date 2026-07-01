// lib/screens/caja_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  State<CajaScreen> createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  Map<String, dynamic>? caja;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    cargarCaja();
  }

  Future<void> cargarCaja() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final response = await ApiClient.get('${Constants.apiUrl}/api/caja/hoy');

    if (!mounted) return;

    if (response != null && response.statusCode == 200) {
      setState(() {
        caja = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  // 🔑 NUEVO: permite al cobrador "crear" la caja manualmente
  // aunque el backend la crea automáticamente al primer pago
  Future<void> _crearCajaInicial() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Iniciar caja del día?'),
        content: const Text(
          'Se creará una caja con base \$0.00. '
          'A medida que cobres se irá actualizando automáticamente. '
          'Al final del día podrás cerrarla con la plata que entregues.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Iniciar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final response = await ApiClient.post('${Constants.apiUrl}/api/caja', {
      'base_entregada': 0,
    });

    if (!mounted) return;

    if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
      await cargarCaja();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Caja del día iniciada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      String mensaje = 'Error al crear caja';
      try {
        final data = jsonDecode(response?.body ?? '{}');
        mensaje = data['error']?.toString() ?? mensaje;
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final fmt = NumberFormat('#,##0', 'es_CO');

    // 🔑 MEJORADO: caja puede ser null o tener tienecaja = false
    final tienecaja = caja?['tienecaja'] == true;
    final base = _toDouble(caja?['base_entregada']);
    final cobrado = _toDouble(caja?['total_cobrado']);
    final totalEntregado = caja?['total_entregado'];
    final pagos = (caja?['pagos_del_dia'] as List?) ?? [];
    final cerrado = tienecaja && totalEntregado != null && totalEntregado > 0;
    final pendientePorEntregar = base + cobrado - (totalEntregado is num ? totalEntregado.toDouble() : 0);

    if (!tienecaja) {
      // 🆕 PANTALLA: No hay caja hoy
      return RefreshIndicator(
        onRefresh: cargarCaja,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: const [
                  Icon(Icons.account_balance_wallet, size: 60, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Sin caja abierta hoy',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'La caja se creará automáticamente cuando registres tu primer cobro del día.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'O puedes iniciarla manualmente con base \$0.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _crearCajaInicial,
              icon: const Icon(Icons.add_circle, color: Colors.white),
              label: const Text('Iniciar caja manualmente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '💡 Tip: Ve a la pestaña de Préstamos y registra tu primer cobro del día. La caja se creará sola con \$0 de base.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // PANTALLA: Caja existe
    return RefreshIndicator(
      onRefresh: cargarCaja,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── ESTADO DE LA CAJA ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cerrado
                    ? Colors.grey.shade100
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: cerrado ? Colors.grey.shade300 : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cerrado ? Icons.lock : Icons.lock_open,
                    color: cerrado ? Colors.grey : Colors.green,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    cerrado ? 'Día cerrado' : 'Caja abierta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cerrado ? Colors.grey : Colors.green,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (cerrado)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('FINALIZADO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('EN CURSO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── KPIs ──
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Base del día',
                    '\$${fmt.format(base)}',
                    Colors.blue.shade50,
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Cobrado sistema',
                    '\$${fmt.format(cobrado)}',
                    Colors.green.shade50,
                    Icons.payments,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Entregado físico',
                    totalEntregado != null
                        ? '\$${fmt.format(_toDouble(totalEntregado))}'
                        : '\$0 (pendiente)',
                    Colors.purple.shade50,
                    Icons.inventory_2,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    cerrado ? 'Diferencia' : 'Pendiente',
                    '\$${fmt.format(pendientePorEntregar)}',
                    pendientePorEntregar >= 0
                        ? Colors.amber.shade50
                        : Colors.red.shade50,
                    Icons.pending_actions,
                    pendientePorEntregar >= 0 ? Colors.amber : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── BARRA DE PROGRESO (cuánto se ha cobrado) ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progreso de cobros del día',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('${pagos.length} pagos',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (pagos.isEmpty ? 0.0 : 1.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.blue.shade100,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── COBROS DEL DÍA ──
            Row(
              children: [
                const Text('Cobros del día',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${pagos.length}',
                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Si está cerrada, mostrar resumen
            if (cerrado)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Caja cerrada. Si cobras más hoy, se reabrirá automáticamente.',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Lista de pagos
            pagos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('Sin cobros aún', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pagos.length,
                    itemBuilder: (_, i) {
                      final p = pagos[i] as Map;
                      final mon = _toDouble(p['monto_pagado'] ?? p['montoPagado']);
                      final nom = _safeStr(
                        p['clientes']?['nombre'] ?? p['prestamos']?['clientes']?['nombre'],
                        defaultValue: 'Cliente',
                      );
                      String hora = '';
                      try {
                        hora = DateFormat('hh:mm a').format(
                          DateTime.parse(p['fecha_pago'].toString()).toLocal(),
                        );
                      } catch (_) {}

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade50,
                          child: const Icon(Icons.check, color: Colors.green, size: 18),
                        ),
                        title: Text(
                          nom,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(hora, style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          '\$${fmt.format(mon)}',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  // Helpers
  double _toDouble(dynamic value, {double defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  String _safeStr(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  Widget _statCard(String titulo, String valor, Color bg, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
