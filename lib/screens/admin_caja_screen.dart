import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class AdminCajaScreen extends StatefulWidget {
  const AdminCajaScreen({super.key});

  @override
  State<AdminCajaScreen> createState() => _AdminCajaScreenState();
}

class _AdminCajaScreenState extends State<AdminCajaScreen> {
  Map<String, dynamic>? resumen;
  List<dynamic> cajas = [];
  bool isLoading = true;
  DateTime fechaSeleccionada = DateTime.now();
  final fmt = NumberFormat('#,##0', 'es_CO');

  @override
  void initState() {
    super.initState();
    cargarResumen();
  }

  String get fechaStr => DateFormat('yyyy-MM-dd').format(fechaSeleccionada);

  Future<void> cargarResumen() async {
    setState(() => isLoading = true);

    final res = await ApiClient.get(
      '${Constants.apiUrl}/api/caja/resumen?fecha=$fechaStr',
    );

    if (!mounted) return;

    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        resumen = data['resumen'];
        cajas = data['cajas'] ?? [];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el resumen de caja'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> abrirModalBase(
    Map<String, dynamic>? cajaExistente,
    String cobradorId,
    String cobradorNombre,
  ) async {
    final ctrl = TextEditingController(
      text: cajaExistente != null
          ? (cajaExistente['baseentregada'] ?? 0).toString()
          : '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Base del día — $cobradorNombre',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto a entregar',
                prefixText: '\$',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(ctrl.text.trim());
                if (monto == null || monto < 0) return;

                final res = await ApiClient.post(
                  '${Constants.apiUrl}/api/caja',
                  {
                    'cobrador_id': cobradorId,
                    'base_entregada': monto,
                    'fecha': fechaStr,
                  },
                );

                if (ctx.mounted) Navigator.pop(ctx);

                if (!mounted) return;
                if (res != null && (res.statusCode == 200 || res.statusCode == 201)) {
                  cargarResumen();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Confirmar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> cerrarCaja(Map<String, dynamic> caja) async {
    final ctrl = TextEditingController(
      text: (caja['totalentregado'] ?? caja['totalcobrado'] ?? 0).toString(),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cierre — ${caja['cobradornombre'] ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Cobrado en sistema: \$${fmt.format(((caja['totalcobrado'] ?? 0) as num).toDouble())}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto que entregó físicamente',
                prefixText: '\$',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(ctrl.text.trim());
                if (monto == null || monto < 0) return;

                final res = await ApiClient.put(
                  '${Constants.apiUrl}/api/caja/${caja['id']}/cerrar',
                  {'total_entregado': monto},
                );

                if (ctx.mounted) Navigator.pop(ctx);

                if (!mounted) return;
                if (res != null && res.statusCode == 200) {
                  cargarResumen();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Cerrar caja',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void mostrarDetalleCaja(Map<String, dynamic> caja) {
    final pagos = (caja['pagosdeldia'] as List?) ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Detalle — ${caja['cobradornombre'] ?? ''}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _fila('Fecha', caja['fecha']?.toString() ?? fechaStr),
              _fila('Base entregada', '\$${fmt.format((caja['baseentregada'] ?? 0) as num)}'),
              _fila('Total cobrado', '\$${fmt.format((caja['totalcobrado'] ?? 0) as num)}'),
              _fila('Total entregado', '\$${fmt.format((caja['totalentregado'] ?? 0) as num)}'),
              _fila(
                'Diferencia',
                '\$${fmt.format((caja['diferencia'] ?? 0) as num)}',
                color: ((caja['diferencia'] ?? 0) as num) >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 20),
              const Text(
                'Pagos del día',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (pagos.isEmpty)
                const Text(
                  'No hay pagos registrados para este cobrador en este día.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...pagos.map((p) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.payments, color: Colors.green),
                      title: Text(
                        '\$${fmt.format((p['monto_pagado'] ?? 0) as num)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Préstamo #${p['prestamo_id'] ?? ''} • ${p['fecha_pago'] ?? ''}',
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja del Día', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFB3E5FC),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: fechaSeleccionada,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => fechaSeleccionada = picked);
                cargarResumen();
              }
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFE1F5FE),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: cargarResumen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (resumen != null) ...[
                      const Text('Resumen General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _kpi('Base entregada', resumen!['totalbaseentregada'], Colors.orange.shade50, Colors.orange),
                          const SizedBox(width: 10),
                          _kpi('Total cobrado', resumen!['totalcobrado'], Colors.green.shade50, Colors.green),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _kpi('Total entregado', resumen!['totalentregado'], Colors.blue.shade50, Colors.blue),
                          const SizedBox(width: 10),
                          _kpi(
                            'Saldo en caja',
                            resumen!['saldocaja'],
                            ((resumen!['saldocaja'] ?? 0) as num) >= 0 ? Colors.teal.shade50 : Colors.red.shade50,
                            ((resumen!['saldocaja'] ?? 0) as num) >= 0 ? Colors.teal : Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                    const Text('Cobradores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    ...cajas.map((c) {
                      final base = ((c['baseentregada'] ?? 0) as num).toDouble();
                      final cobrado = ((c['totalcobrado'] ?? 0) as num).toDouble();
                      final entregado = c['totalentregado'];
                      final cerrado = entregado != null;
                      final diff = (c['diferencia'] ?? 0) as num;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => mostrarDetalleCaja(c),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      c['cobradornombre'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: cerrado ? Colors.grey.shade100 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        cerrado ? 'Cerrado' : 'Abierto',
                                        style: TextStyle(
                                          color: cerrado ? Colors.grey : Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _fila('Base entregada', '\$${fmt.format(base)}'),
                                _fila('Cobrado en sistema', '\$${fmt.format(cobrado)}'),
                                if (cerrado) ...[
                                  _fila('Entregó físicamente', '\$${fmt.format((entregado as num).toDouble())}'),
                                  _fila(
                                    'Diferencia',
                                    '\$${fmt.format(diff.toDouble())}',
                                    color: diff >= 0 ? Colors.green : Colors.red,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => abrirModalBase(
                                          c,
                                          c['usuariosid'].toString(),
                                          c['cobradornombre'] ?? '',
                                        ),
                                        icon: const Icon(Icons.account_balance_wallet, size: 16),
                                        label: Text(base > 0 ? 'Editar base' : 'Dar base'),
                                      ),
                                    ),
                                    if (!cerrado && base > 0) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => cerrarCaja(c),
                                          icon: const Icon(Icons.lock, size: 16),
                                          label: const Text('Cerrar'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _kpi(String titulo, dynamic valor, Color bg, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '\$${fmt.format((valor as num?)?.toDouble() ?? 0)}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String label, String valor, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            valor,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}