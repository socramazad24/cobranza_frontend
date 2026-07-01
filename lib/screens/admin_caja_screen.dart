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
  List cajas = [];
  bool isLoading = true;
  DateTime fechaSeleccionada = DateTime.now();
  final fmt = NumberFormat('#,##0', 'es_CO');

  @override
  void initState() {
    super.initState();
    cargarResumen();
  }

  String get fechaStr => DateFormat('yyyy-MM-dd').format(fechaSeleccionada);

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  double _sumarCampo(List items, String key) {
    double total = 0;
    for (final item in items) {
      if (item is Map && item[key] != null) {
        total += _toDouble(item[key]);
      }
    }
    return total;
  }

  Future<void> cargarResumen() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final res = await ApiClient.get(
      '${Constants.apiUrl}/api/caja/resumen?fecha=$fechaStr',
    );

    if (!mounted) return;

    if (res != null && res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      setState(() {
        resumen = data['resumen'] as Map<String, dynamic>?;
        cajas = (data['cajas'] as List?) ?? [];
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);

      String mensaje = 'No se pudo cargar el resumen de caja';
      try {
        final body = jsonDecode(res?.body ?? '{}');
        mensaje = body['error'] ?? mensaje;
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> abrirModalBase(
    Map? cajaExistente,
    String cobradorId,
    String cobradorNombre,
  ) async {
    final ctrl = TextEditingController(
      text: cajaExistente != null
          ? (cajaExistente['base_entregada'] ?? 0).toString()
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
              'Base del día - $cobradorNombre',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto a entregar',
                prefixText: '\$ ',
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
                  await cargarResumen();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Base registrada correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  String mensaje = 'No se pudo guardar la base';
                  try {
                    final body = jsonDecode(res?.body ?? '{}');
                    mensaje = body['error'] ?? mensaje;
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
                  );
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

  Future<void> cerrarCaja(Map caja) async {
    final ctrl = TextEditingController(
      text: (caja['total_entregado'] ?? caja['total_cobrado'] ?? 0).toString(),
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
              'Cierre - ${caja['cobradornombre'] ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Cobrado en sistema: \$${fmt.format(_toDouble(caja['total_cobrado']))}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto entregado físicamente',
                prefixText: '\$ ',
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
                  await cargarResumen();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Caja cerrada correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  String mensaje = 'No se pudo cerrar la caja';
                  try {
                    final body = jsonDecode(res?.body ?? '{}');
                    mensaje = body['error'] ?? mensaje;
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
                  );
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

  Future<void> reabrirCaja(Map caja) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reabrir caja?'),
        content: Text(
          'La caja de ${caja['cobradornombre'] ?? ''} quedará abierta nuevamente. '
          'El dinero pendiente volverá a acumularse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reabrir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final res = await ApiClient.put(
      '${Constants.apiUrl}/api/caja/${caja['id']}/reabrir',
      {},
    );

    if (!mounted) return;

    if (res != null && res.statusCode == 200) {
      await cargarResumen();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caja reabierta correctamente'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      String mensaje = 'No se pudo reabrir la caja';
      try {
        final body = jsonDecode(res?.body ?? '{}');
        mensaje = body['error'] ?? mensaje;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> editarMontoRecibido(Map caja) async {
    final ctrl = TextEditingController(
      text: (caja['total_entregado'] ?? 0).toString(),
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
              'Editar monto recibido - ${caja['cobradornombre'] ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Este cambio no queda en el historial.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto recibido físicamente',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(ctrl.text.trim());
                if (monto == null || monto < 0) return;

                final res = await ApiClient.put(
                  '${Constants.apiUrl}/api/caja/${caja['id']}/monto-recibido',
                  {'total_entregado': monto},
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;

                if (res != null && res.statusCode == 200) {
                  await cargarResumen();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Monto actualizado correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  String mensaje = 'No se pudo actualizar el monto';
                  try {
                    final body = jsonDecode(res?.body ?? '{}');
                    mensaje = body['error'] ?? mensaje;
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: fechaSeleccionada,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      setState(() => fechaSeleccionada = fecha);
      await cargarResumen();
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalBase = 0;
    double totalCobrado = 0;
    double totalEntregado = 0;

    for (final caja in cajas) {
      if (caja is Map) {
        totalBase += _toDouble(caja['base_entregada']);
        totalCobrado += _toDouble(caja['total_cobrado']);
        totalEntregado += _toDouble(caja['total_entregado']);
      }
    }

    final saldoCaja = totalBase + totalCobrado - totalEntregado;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Administración de Caja',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE3F2FD),
        actions: [
          IconButton(
            onPressed: seleccionarFecha,
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: cargarResumen,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy').format(fechaSeleccionada)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _statCard(
                        'Base entregada',
                        fmt.format(totalBase),
                        Colors.blue.shade50,
                        Icons.account_balance_wallet,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        'Cobrado sistema',
                        fmt.format(totalCobrado),
                        Colors.green.shade50,
                        Icons.payments,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard(
                        'Entregado físico',
                        fmt.format(totalEntregado),
                        Colors.purple.shade50,
                        Icons.inventory_2,
                        Colors.purple,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        'Saldo caja',
                        fmt.format(saldoCaja),
                        saldoCaja >= 0 ? Colors.amber.shade50 : Colors.red.shade50,
                        Icons.pending_actions,
                        saldoCaja >= 0 ? Colors.amber : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cajas por cobrador',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  if (cajas.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay cajas registradas para esta fecha.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ...cajas.map((caja) {
                    final base = _toDouble(caja['base_entregada']);
                    final cobrado = _toDouble(caja['total_cobrado']);
                    final entregado = _toDouble(caja['total_entregado']);
                    final cerrada = caja['total_entregado'] != null;
                    final pendiente = base + cobrado - entregado;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade50,
                                  child: const Icon(Icons.person, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    caja['cobradornombre'] ?? 'Sin nombre',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cerrada
                                        ? Colors.grey.shade200
                                        : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    cerrada ? 'Cerrada' : 'Activa',
                                    style: TextStyle(
                                      color: cerrada
                                          ? Colors.grey.shade700
                                          : Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _filaMonto('Base entregada', base),
                            _filaMonto('Cobrado en sistema', cobrado),
                            _filaMonto('Entregado físicamente', entregado),
                            _filaMonto('Pendiente por entregar', pendiente),
                            if (cerrada && pendiente > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Se cobró más dinero después del cierre. Pendiente: \$${fmt.format(pendiente)}',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => abrirModalBase(
                                      caja,
                                      caja['cobrador_id'].toString(),
                                      caja['cobradornombre'] ?? '',
                                    ),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Editar base'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: cerrada ? null : () => cerrarCaja(caja),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    icon: const Icon(Icons.lock, color: Colors.white),
                                    label: const Text(
                                      'Cerrar caja',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (cerrada)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => reabrirCaja(caja),
                                      icon: const Icon(
                                        Icons.lock_open,
                                        color: Colors.orange,
                                      ),
                                      label: const Text(
                                        'Reabrir caja',
                                        style: TextStyle(color: Colors.orange),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.orange),
                                      ),
                                    ),
                                  ),
                                if (cerrada) const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => editarMontoRecibido(caja),
                                    icon: const Icon(
                                      Icons.edit_note,
                                      color: Colors.purple,
                                    ),
                                    label: const Text(
                                      'Editar monto',
                                      style: TextStyle(color: Colors.purple),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.purple),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _filaMonto(String label, double monto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '\$${fmt.format(monto)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String titulo,
    String valor,
    Color bg,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}