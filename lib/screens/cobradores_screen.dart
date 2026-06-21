// lib/screens/cobradores_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cobrador_service.dart';

class CobradoresScreen extends StatefulWidget {
  const CobradoresScreen({super.key});

  @override
  State<CobradoresScreen> createState() => _CobradoresScreenState();
}

class _CobradoresScreenState extends State<CobradoresScreen> {
  final CobradorService _cobradorService = CobradorService();
  List<dynamic> _cobradores = [];
  List<dynamic> _rutas = [];
  bool _isLoading = true;
  bool _esAdmin = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final rol = prefs.getString('user_rol') ?? 'cobrador';
    _esAdmin = rol == 'admin';

    if (_esAdmin) {
      final results = await Future.wait([
        _cobradorService.getCobradores(),
        _cobradorService.getRutas(),
      ]);
      setState(() {
        _cobradores = results[0];
        _rutas = results[1];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_esAdmin && !_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFE8F5E9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Acceso restringido',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              const Text(
                'Solo los administradores\npueden ver esta sección.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      floatingActionButton: _esAdmin
          ? FloatingActionButton.extended(
              onPressed: () => abrirFormularioNuevoCobrador(
                context,
                _rutas,
                _cargarDatos,
              ),
              backgroundColor: const Color(0xFFA5D6A7),
              icon: const Icon(Icons.person_add),
              label: const Text('Nuevo Cobrador',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cobradores.isEmpty
              ? const Center(
                  child: Text('No hay cobradores registrados.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _cobradores.length,
                  itemBuilder: (context, index) {
                    final cobrador = _cobradores[index];
                    final rutas = (cobrador['rutas'] as List?)
                            ?.map((r) => r['nombre'].toString())
                            .join(', ') ??
                        'Sin rutas';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green[200],
                          child: Text(
                            cobrador['nombre'].toString()[0].toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ),
                        title: Text(cobrador['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: Row(
                          children: [
                            const Icon(Icons.route,
                                size: 13, color: Colors.green),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(rutas,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
    );
  }
}

// ── Función global reutilizable ───────────────────────────────
void abrirFormularioNuevoCobrador(
  BuildContext context,
  List<dynamic> rutas,
  VoidCallback onCreado,
) {
  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final CobradorService cobradorService = CobradorService();
  List<int> rutasSeleccionadas = [];
  bool obscurePassword = true;
  bool guardando = false;

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
              const Text('Nuevo Cobrador',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Nombre (solo letras)
              TextField(
                controller: nombreController,
                keyboardType: TextInputType.name,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Nombre completo *',
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'Solo letras',
                ),
              ),
              const SizedBox(height: 12),

              // Correo
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico *',
                  prefixIcon: Icon(Icons.email_outlined),
                  hintText: 'ejemplo@correo.com',
                ),
              ),
              const SizedBox(height: 12),

              // Contraseña
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  hintText: 'Mínimo 6 caracteres',
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setModalState(
                        () => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Rutas chips
              const Text('Rutas asignadas *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              const Text('Selecciona una o más rutas',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              rutas.isEmpty
                  ? const Text('No hay rutas disponibles',
                      style: TextStyle(color: Colors.grey))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: rutas.map((ruta) {
                        final id = ruta['id'] as int;
                        final nombre = ruta['nombre'].toString();
                        final seleccionada =
                            rutasSeleccionadas.contains(id);
                        return FilterChip(
                          label: Text(nombre),
                          selected: seleccionada,
                          selectedColor: const Color(0xFFA5D6A7),
                          checkmarkColor: Colors.green[800],
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                rutasSeleccionadas.add(id);
                              } else {
                                rutasSeleccionadas.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 24),

              // Botón guardar
              guardando
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();

                        if (nombre.isEmpty ||
                            email.isEmpty ||
                            password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Todos los campos son requeridos')),
                          );
                          return;
                        }
                        if (password.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Contraseña mínimo 6 caracteres')),
                          );
                          return;
                        }
                        if (rutasSeleccionadas.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Selecciona al menos una ruta')),
                          );
                          return;
                        }
                        if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$')
                            .hasMatch(email)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Correo electrónico inválido')),
                          );
                          return;
                        }

                        setModalState(() => guardando = true);

                        final success = await cobradorService.createCobrador(
                          nombre,
                          email,
                          password,
                          rutasSeleccionadas,
                        );

                        setModalState(() => guardando = false);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '✅ Cobrador creado correctamente'
                                  : '❌ Error al crear cobrador'),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                          if (success) onCreado();
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Cobrador',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA5D6A7),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
            ],
          ),
        ),
      ),
    ),
  );
}