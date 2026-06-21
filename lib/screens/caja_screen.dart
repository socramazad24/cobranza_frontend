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
    setState(() => isLoading = true);
    final response = await ApiClient.get('${Constants.apiUrl}/api/caja/hoy');
    if (response != null && response.statusCode == 200) {
      setState(() {
        caja = jsonDecode(response.body);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    final tieneCaja  = caja?['tiene_caja'] == true;
    final base       = (caja?['base_entregada'] as num?)?.toDouble() ?? 0;
    final cobrado    = (caja?['total_cobrado'] as num?)?.toDouble() ?? 0;
    final fmt        = NumberFormat('#,##0', 'es_CO');
    final pagos      = (caja?['pagos_del_dia'] as List?) ?? [];
    final cerrado    = caja?['total_entregado'] != null;

    return RefreshIndicator(
      onRefresh: cargarCaja,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner estado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: !tieneCaja
                    ? Colors.orange.shade50
                    : cerrado
                        ? Colors.grey.shade100
                        : Colors.green.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: !tieneCaja
                      ? Colors.orange.shade200
                      : cerrado
                          ? Colors.grey.shade300
                          : Colors.green.shade200,
                ),
              ),
              child: Row(children: [
                Icon(
                  !tieneCaja ? Icons.warning_amber : cerrado ? Icons.lock : Icons.lock_open,
                  color: !tieneCaja ? Colors.orange : cerrado ? Colors.grey : Colors.green,
                ),
                const SizedBox(width: 10),
                Text(
                  !tieneCaja
                      ? 'Sin base asignada hoy'
                      : cerrado
                          ? 'Día cerrado'
                          : 'Día activo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: !tieneCaja ? Colors.orange : cerrado ? Colors.grey : Colors.green,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Tarjetas de resumen
            Row(children: [
              _statCard('Base del día', '\$${fmt.format(base)}', Colors.blue.shade50, Icons.account_balance_wallet, Colors.blue),
              const SizedBox(width: 12),
              _statCard('Cobrado hoy', '\$${fmt.format(cobrado)}', Colors.green.shade50, Icons.payments, Colors.green),
            ]),
            const SizedBox(height: 12),

            // Total disponible (base + cobrado)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a entregar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    '\$${fmt.format(base + cobrado)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.amber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Desglose de pagos del día
            const Text('Cobros del día', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            pagos.isEmpty
                ? const Text('Sin cobros registrados hoy', style: TextStyle(color: Colors.grey))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pagos.length,
                    itemBuilder: (_, i) {
                      final p   = pagos[i];
                      final mon = (p['monto_pagado'] as num?)?.toDouble() ?? 0;
                      final nom = p['prestamos']?['clientes']?['nombre'] ?? 'Cliente';
                      final hora = DateFormat('hh:mm a').format(DateTime.parse(p['fecha_pago']).toLocal());
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(Icons.check, color: Colors.green)),
                        title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(hora),
                        trailing: Text('\$${fmt.format(mon)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String titulo, String valor, Color bg, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}