// lib/screens/observaciones_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/observacion_service.dart';

class ObservacionesScreen extends StatefulWidget {
  const ObservacionesScreen({super.key});

  @override
  State<ObservacionesScreen> createState() => _ObservacionesScreenState();
}

class _ObservacionesScreenState extends State<ObservacionesScreen>
    with SingleTickerProviderStateMixin {
  final ObservacionService _service = ObservacionService();
  List<dynamic> _pendientes = [];
  List<dynamic> _resueltas = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarObservaciones();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarObservaciones() async {
    setState(() => _isLoading = true);
    final pendientes = await _service.getObservaciones(resuelta: false);
    final resueltas = await _service.getObservaciones(resuelta: true);
    setState(() {
      _pendientes = pendientes;
      _resueltas = resueltas;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Observaciones',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFE0B2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'Pendientes (${_pendientes.length})'),
            Tab(text: 'Resueltas (${_resueltas.length})'),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFFFF3E0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLista(_pendientes, pendiente: true),
                _buildLista(_resueltas, pendiente: false),
              ],
            ),
    );
  }

  Widget _buildLista(List<dynamic> lista, {required bool pendiente}) {
    if (lista.isEmpty) {
      return Center(
        child: Text(
          pendiente
              ? '✅ Sin observaciones pendientes'
              : 'Sin observaciones resueltas',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final obs = lista[index];
        final cobrador = obs['usuarios']?['nombre'] ?? 'Desconocido';

        // ✅ Corrección: usar 'prestamo_data' en lugar de 'prestamos'
        final prestamo = obs['prestamo_data'];
        final cliente = prestamo?['clientes'];

        final fecha = DateFormat('dd MMM yyyy – hh:mm a')
            .format(DateTime.parse(obs['created_at']).toLocal());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tipo + referencia ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        obs['tipo'].toString().toUpperCase(),
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ),
                    Text('Ref: #${obs['referencia_id']}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Datos del cliente y préstamo ──
                if (cliente != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      Text(
                        cliente['nombre'] ?? 'Sin nombre',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  if (cliente['telefono'] != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(cliente['telefono'],
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ],
                  if (prestamo != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.attach_money,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Préstamo: \$${double.parse(prestamo['monto_prestado'].toString()).toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                ],

                // ── Descripción ──
                Text(obs['descripcion'],
                    style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 8),

                // ── Cobrador y fecha ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Por: $cobrador',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    Text(fecha,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),

                // ── Botón resolver ──
                if (pendiente) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final success = await _service
                            .resolverObservacion(obs['id'] as int);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '✅ Observación marcada como resuelta'
                                  : '❌ Error al resolver'),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                          if (success) _cargarObservaciones();
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline,
                          size: 18),
                      label: const Text('Marcar como resuelta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}