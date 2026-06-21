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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                if (res != null &&
                    (res.statusCode == 200 || res.statusCode == 201)) {
                  cargarResumen();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Confirmar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cobrado en sistema: \$${fmt.format(((caja['totalcobrado'] ?? 0) as num).toDouble())}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto entregado físicamente',
                prefixText: '\$',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(ctrl.text.trim());
                if (monto == null || monto < 0) return;

                final res = await ApiClient.post(
                  '${Constants.apiUrl}/api/caja/cerrar',
                  {
                    'caja_id': caja['id'],
                    'total_entregado': monto,
                  },
                );

                if (ctx.mounted) Navigator.pop(ctx);

                if (!mounted) return;

                if (res != null && res.statusCode == 200) {
                  cargarResumen();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Caja cerrada correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo cerrar la caja'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Cerrar caja',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
      cargarResumen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBase =
        (resumen?['total_base_entregada'] as num?)?.toDouble() ?? 0;
    final totalCobrado =
        (resumen?['total_cobrado'] as num?)?.toDouble() ?? 0;
    final totalEntregado =
        (resumen?['total_entregado'] as num?)?.toDouble() ?? 0;
    final pendienteGeneral = totalBase + totalCobrado - totalEntregado;

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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _statCard(
                        'Base entregada',
                        '\$${fmt.format(totalBase)}',
                        Colors.blue.shade50,
                        Icons.account_balance_wallet,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        'Cobrado sistema',
                        '\$${fmt.format(totalCobrado)}',
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
                        '\$${fmt.format(totalEntregado)}',
                        Colors.purple.shade50,
                        Icons.inventory_2,
                        Colors.purple,
                      ),
                      const SizedBox(width: 12),
                      _statCard(
                        'Pendiente general',
                        '\$${fmt.format(pendienteGeneral)}',
                        pendienteGeneral >= 0
                            ? Colors.amber.shade50
                            : Colors.red.shade50,
                        Icons.pending_actions,
                        pendienteGeneral >= 0 ? Colors.amber : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cajas por cobrador',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 12),
                  ...cajas.map((caja) {
                    final base =
                        ((caja['baseentregada'] ?? 0) as num).toDouble();
                    final cobrado =
                        ((caja['totalcobrado'] ?? 0) as num).toDouble();
                    final entregado =
                        ((caja['totalentregado'] ?? 0) as num?)?.toDouble();
                    final cerrada = entregado != null && entregado > 0;
                    final pendiente = base + cobrado - (entregado ?? 0);

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
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                  ),
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
                            _filaMonto(
                              'Entregado físicamente',
                              entregado ?? 0,
                            ),
                            _filaMonto('Pendiente por entregar', pendiente),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => abrirModalBase(
                                      caja,
                                      caja['cobradorid'].toString(),
                                      caja['cobradornombre'] ?? '',
                                    ),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Editar base'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: cerrada
                                        ? null
                                        : () => cerrarCaja(caja),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    icon: const Icon(
                                      Icons.lock,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Cerrar caja',
                                      style: TextStyle(color: Colors.white),
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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