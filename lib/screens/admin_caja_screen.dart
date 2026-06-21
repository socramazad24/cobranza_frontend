import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final res = await ApiClient.get('${Constants.apiUrl}/api/caja/resumen?fecha=$fechaStr');
    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        resumen = data['resumen'];
        cajas = data['cajas'];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _abrirModalBase(Map<String, dynamic>? cajaExistente, String cobradorId, String cobradorNombre) async {
    final ctrl = TextEditingController(
        text: cajaExistente != null ? cajaExistente['base_entregada'].toString() : '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Base del día — $cobradorNombre', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monto a entregar', prefixText: '\$'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final monto = double.tryParse(ctrl.text);
              if (monto == null) return;
              await ApiClient.post('${Constants.apiUrl}/api/caja', {
                'cobrador_id': cobradorId,
                'base_entregada': monto,
                'fecha': fechaStr,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              cargarResumen();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Future<void> _cerrarCaja(Map<String, dynamic> caja) async {
    final ctrl = TextEditingController(text: caja['total_cobrado'].toString());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Cierre — ${caja['cobrador_nombre']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Cobrado en sistema: \$${fmt.format((caja['total_cobrado'] as num).toDouble())}',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monto que entregó físicamente',
              prefixText: '\$',
              helperText: 'Puede diferir si hubo errores o gastos en ruta',
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final monto = double.tryParse(ctrl.text);
              if (monto == null) return;
              await ApiClient.put(
                '${Constants.apiUrl}/api/caja/${caja['id']}/cerrar',
                {'total_entregado': monto},
              );
              if (ctx.mounted) Navigator.pop(ctx);
              cargarResumen();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Cerrar caja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Resumen general del día
                  if (resumen != null) ...[
                    const Text('Resumen General', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _kpi('Base entregada', resumen!['total_base_entregada'], Colors.orange.shade50, Colors.orange),
                      const SizedBox(width: 10),
                      _kpi('Total cobrado', resumen!['total_cobrado'], Colors.green.shade50, Colors.green),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      _kpi('Total entregado', resumen!['total_entregado'], Colors.blue.shade50, Colors.blue),
                      const SizedBox(width: 10),
                      _kpi('Saldo en caja', resumen!['saldo_caja'], 
                        (resumen!['saldo_caja'] as num) >= 0 ? Colors.teal.shade50 : Colors.red.shade50,
                        (resumen!['saldo_caja'] as num) >= 0 ? Colors.teal : Colors.red),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // Lista de cobradores del día
                  const Text('Cobradores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ...cajas.map((c) {
                    final base     = (c['base_entregada'] as num).toDouble();
                    final cobrado  = (c['total_cobrado'] as num).toDouble();
                    final entregado = c['total_entregado'];
                    final cerrado  = entregado != null;
                    final diff     = c['diferencia'] as num?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(c['cobrador_nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: cerrado ? Colors.grey.shade100 : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(cerrado ? 'Cerrado' : 'Abierto',
                                  style: TextStyle(
                                    color: cerrado ? Colors.grey : Colors.green,
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          _fila('Base entregada', '\$${fmt.format(base)}'),
                          _fila('Cobrado en sistema', '\$${fmt.format(cobrado)}'),
                          if (cerrado) ...[
                            _fila('Entregó físicamente', '\$${fmt.format((entregado as num).toDouble())}'),
                            _fila('Diferencia',
                              '\$${fmt.format(diff?.toDouble() ?? 0)}',
                              color: (diff ?? 0) >= 0 ? Colors.green : Colors.red),
                          ],
                          const SizedBox(height: 10),
                          Row(children: [
                            // Botón asignar/editar base
                            Expanded(child: OutlinedButton.icon(
                              onPressed: () => _abrirModalBase(c, c['usuarios']['id'], c['cobrador_nombre']),
                              icon: const Icon(Icons.account_balance_wallet, size: 16),
                              label: Text(base > 0 ? 'Editar base' : 'Dar base'),
                            )),
                            if (!cerrado && base > 0) ...[
                              const SizedBox(width: 10),
                              Expanded(child: ElevatedButton.icon(
                                onPressed: () => _cerrarCaja(c),
                                icon: const Icon(Icons.lock, size: 16),
                                label: const Text('Cerrar'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              )),
                            ],
                          ]),
                        ]),
                      ),
                    );
                  }),
                ]),
              ),
            ),
    );
  }

  Widget _kpi(String titulo, dynamic valor, Color bg, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('\$${fmt.format((valor as num?)?.toDouble() ?? 0)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );

  Widget _fila(String label, String valor, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      Text(valor, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
    ]),
  );
}