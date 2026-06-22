// lib/screens/admin_panel_screen.dart
import 'package:flutter/material.dart';
import 'package:frontend_flutter/screens/observaciones_screen.dart';
import 'package:frontend_flutter/utils/constants.dart';
import '../utils/http_client.dart';
import '../services/admin_service.dart';
import '../services/cobrador_service.dart';
import 'cobradores_screen.dart';
import 'rutas_screen.dart';
import 'admin_caja_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AdminService _adminService = AdminService();
  final CobradorService _cobradorService = CobradorService();

  List _usuarios = [];
  List _rutas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final results = await Future.wait([
      _adminService.getAllUsers(),
      _cobradorService.getRutas(),
    ]);

    if (!mounted) return;

    setState(() {
      _usuarios = results[0];
      _rutas = results[1];
      _isLoading = false;
    });
  }

  void _abrirEditorUsuario(Map usuario) async {
    final nombreController =
        TextEditingController(text: usuario['nombre']?.toString() ?? '');
    String rolSeleccionado = usuario['rol']?.toString() ?? 'cobrador';

    List rutasActuales = [];
    if (rolSeleccionado == 'cobrador') {
      rutasActuales = await _cobradorService.getRutasDeCobrador(
        usuario['id'].toString(),
      );
    }

    List<String> rutasSeleccionadas = rutasActuales
        .map<String>((r) => r['id'].toString())
        .toList();

    if (!mounted) return;

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Editar Usuario',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Rol',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: rolSeleccionado,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Administrador'),
                    ),
                    DropdownMenuItem(
                      value: 'cobrador',
                      child: Text('Cobrador'),
                    ),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;

                    setModalState(() => rolSeleccionado = value);

                    if (rolSeleccionado == 'cobrador') {
                      final rutas = await _cobradorService.getRutasDeCobrador(
                        usuario['id'].toString(),
                      );

                      rutasSeleccionadas = rutas
                          .map<String>((r) => r['id'].toString())
                          .toList();

                      if (context.mounted) {
                        setModalState(() {});
                      }
                    } else {
                      rutasSeleccionadas = [];
                      setModalState(() {});
                    }
                  },
                ),
                const SizedBox(height: 20),
                if (rolSeleccionado == 'cobrador') ...[
                  const Text(
                    'Rutas asignadas',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Selecciona o deselecciona rutas',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _rutas.isEmpty
                      ? const Text(
                          'No hay rutas disponibles',
                          style: TextStyle(color: Colors.grey),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _rutas.map((ruta) {
                            final id = ruta['id'].toString();
                            final nombre = ruta['nombre'].toString();
                            final sel = rutasSeleccionadas.contains(id);

                            return FilterChip(
                              label: Text(nombre),
                              selected: sel,
                              selectedColor: const Color(0xFFA5D6A7),
                              checkmarkColor: Colors.green[800],
                              onSelected: (v) => setModalState(() {
                                if (v) {
                                  if (!rutasSeleccionadas.contains(id)) {
                                    rutasSeleccionadas.add(id);
                                  }
                                } else {
                                  rutasSeleccionadas.remove(id);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                  const SizedBox(height: 20),
                ],
                ElevatedButton(
                  onPressed: () async {
                    final nombre = nombreController.text.trim();

                    if (nombre.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('El nombre es obligatorio'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    if (rolSeleccionado == 'cobrador' &&
                        rutasSeleccionadas.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Selecciona al menos una ruta'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    final success = await _adminService.updateUser(
                      usuario['id'],
                      nombre,
                      rolSeleccionado,
                    );

                    bool rutasOk = true;

                    if (success && rolSeleccionado == 'cobrador') {
                      final rutasRes = await ApiClient.put(
                        '${Constants.apiUrl}/api/rutas/cobrador/${usuario['id']}',
                        {
                          'ruta_ids': rutasSeleccionadas,
                        },
                      );

                      rutasOk = rutasRes != null &&
                          (rutasRes.statusCode == 200 ||
                              rutasRes.statusCode == 201);
                    }

                    if (!context.mounted) return;

                    Navigator.pop(context);

                    final actualizado = success && rutasOk;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          actualizado
                              ? '✅ Usuario actualizado'
                              : '❌ Error al actualizar',
                        ),
                        backgroundColor:
                            actualizado ? Colors.green : Colors.red,
                      ),
                    );

                    if (actualizado) {
                      _cargarDatos();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF81D4FA),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Guardar Cambios',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(Map usuario) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text(
          '¿Estás seguro de que quieres eliminar a "${usuario['nombre']}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await _adminService.deleteUser(usuario['id']);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? '✅ Usuario eliminado' : '❌ Error al eliminar',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );

              if (success) {
                _cargarDatos();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel Administrador',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFE1F5FE),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            abrirFormularioNuevoCobrador(context, _rutas, _cargarDatos),
        backgroundColor: const Color(0xFF81D4FA),
        icon: const Icon(Icons.person_add),
        label: const Text(
          'Nuevo Cobrador',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RutasScreen()),
                    ),
                    icon: const Icon(Icons.map, color: Colors.white),
                    label: const Text(
                      'Gestionar Rutas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ObservacionesScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.report_problem_outlined,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Ver Observaciones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminCajaScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Caja del Día',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Usuarios del Sistema',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _usuarios.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay usuarios registrados',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          itemCount: _usuarios.length,
                          itemBuilder: (context, index) {
                            final usuario = _usuarios[index];
                            final esAdmin = usuario['rol'] == 'admin';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      esAdmin ? Colors.blue[100] : Colors.green[100],
                                  child: Icon(
                                    esAdmin
                                        ? Icons.admin_panel_settings
                                        : Icons.person,
                                    color: esAdmin ? Colors.blue : Colors.green,
                                  ),
                                ),
                                title: Text(
                                  usuario['nombre'] ?? 'Sin nombre',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: esAdmin
                                            ? Colors.blue[50]
                                            : Colors.green[50],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        esAdmin ? 'Admin' : 'Cobrador',
                                        style: TextStyle(
                                          color: esAdmin
                                              ? Colors.blue
                                              : Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: 18,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _abrirEditorUsuario(usuario),
                                    ),
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _confirmarEliminar(usuario),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}