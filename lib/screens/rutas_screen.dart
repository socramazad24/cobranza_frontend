// lib/screens/rutas_screen.dart
import 'package:flutter/material.dart';
import '../services/ruta_service.dart';
import '../services/cobrador_service.dart';

class RutasScreen extends StatefulWidget {
  const RutasScreen({super.key});

  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  final RutaService _rutaService = RutaService();
  final CobradorService _cobradorService = CobradorService();

  List _rutas = [];
  List _cobradores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final rutas = await _rutaService.getRutas();
    final cobradores = await _cobradorService.getCobradores();

    if (!mounted) return;

    setState(() {
      _rutas = rutas;
      _cobradores = cobradores;
      _isLoading = false;
    });
  }

  void _crearRuta() {
    final nombreController = TextEditingController();
    final descController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nueva Ruta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la ruta',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.trim().isEmpty) return;

                final success = await _rutaService.createRuta(
                  nombreController.text.trim(),
                  descController.text.trim(),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? '✅ Ruta creada' : '❌ Error al crear ruta',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  if (success) {
                    _cargarDatos();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Guardar Ruta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _asignarCobrador(Map ruta) {
    final List<String> seleccionados = [];
    final dynamic rutaId = ruta['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Asignar cobradores a "${ruta['nombre']}"',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _cobradores.isEmpty
                  ? const Text(
                      'No hay cobradores disponibles',
                      style: TextStyle(color: Colors.grey),
                    )
                  : Column(
                      children: _cobradores.map((cobrador) {
                        final id = cobrador['id'].toString();

                        return CheckboxListTile(
                          title: Text(cobrador['nombre'] ?? 'Sin nombre'),
                          value: seleccionados.contains(id),
                          onChanged: (checked) {
                            setModalState(() {
                              if (checked == true) {
                                if (!seleccionados.contains(id)) {
                                  seleccionados.add(id);
                                }
                              } else {
                                seleccionados.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (seleccionados.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selecciona al menos un cobrador'),
                      ),
                    );
                    return;
                  }

                  bool todoOk = true;

                  for (final cobradorId in seleccionados) {
                    final ok = await _rutaService.asignarRutas(
                      cobradorId,
                      [rutaId],
                    );
                    if (!ok) {
                      todoOk = false;
                    }
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          todoOk
                              ? '✅ Cobradores asignados'
                              : '❌ Error al asignar uno o más cobradores',
                        ),
                        backgroundColor:
                            todoOk ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Confirmar Asignación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminarRuta(Map ruta) async {
    final rutaId = ruta['id'].toString();

    Map? resumen;
    try {
      resumen = await _rutaService.getResumenRuta(rutaId);
    } catch (_) {}

    final resumenData = resumen?['resumen'] as Map?;
    final advertencia = resumen?['advertencia']?.toString();

    final clientes = resumenData?['clientes'] ?? 0;
    final prestamosTotal = resumenData?['prestamos_total'] ?? 0;
    final prestamosActivos = resumenData?['prestamos_activos'] ?? 0;
    final pagos = resumenData?['pagos'] ?? 0;

    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Ruta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Eliminar "${ruta['nombre']}"?'),
            const SizedBox(height: 12),
            if (resumen != null) ...[
              Text('Clientes: $clientes'),
              Text('Préstamos: $prestamosTotal'),
              Text('Préstamos activos: $prestamosActivos'),
              Text('Pagos: $pagos'),
              if (advertencia != null && advertencia.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    '⚠️ $advertencia',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ] else ...[
              const Text(
                'Esta acción eliminará la ruta y sus datos relacionados.',
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await _rutaService.deleteRuta(rutaId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '✅ Ruta eliminada' : '❌ Error al eliminar',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        _cargarDatos();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestión de Rutas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFB3E5FC),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFE1F5FE),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crearRuta,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Ruta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rutas.isEmpty
              ? const Center(
                  child: Text(
                    'No hay rutas creadas.\nPresiona + para agregar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _rutas.length,
                  itemBuilder: (context, index) {
                    final ruta = _rutas[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(Icons.map, color: Colors.blue),
                        ),
                        title: Text(
                          ruta['nombre'] ?? 'Sin nombre',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          ruta['descripcion'] ?? 'Sin descripción',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person_add,
                                  color: Colors.green,
                                  size: 18,
                                ),
                              ),
                              onPressed: () => _asignarCobrador(ruta),
                            ),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 18,
                                ),
                              ),
                              onPressed: () => _confirmarEliminarRuta(ruta),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}