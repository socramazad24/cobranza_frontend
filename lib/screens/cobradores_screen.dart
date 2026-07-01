// lib/screens/cobradores_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cobrador_service.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class CobradoresScreen extends StatefulWidget {
  const CobradoresScreen({super.key});

  @override
  State<CobradoresScreen> createState() => _CobradoresScreenState();
}

class _CobradoresScreenState extends State<CobradoresScreen> {
  final CobradorService _cobradorService = CobradorService();

  List _cobradores = [];
  List _rutas = [];
  bool _isLoading = true;
  bool _esAdmin = false;

  final Map<String, List> _prestamosPorCobrador = {};
  final Map<String, bool> _loadingPrestamos = {};
  final Map<String, String?> _errorPrestamos = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final rol =
        prefs.getString('user_rol') ?? prefs.getString('userrol') ?? 'cobrador';

    _esAdmin = rol == 'admin';

    if (_esAdmin) {
      final results = await Future.wait([
        _cobradorService.getCobradores(),
        _cobradorService.getRutas(),
      ]);

      if (!mounted) return;

      setState(() {
        _cobradores = results[0];
        _rutas = results[1];
        _isLoading = false;
        _prestamosPorCobrador.clear();
        _errorPrestamos.clear();
      });
    } else {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPrestamosDeCobrador(String cobradorId) async {
    if (_prestamosPorCobrador.containsKey(cobradorId)) return;

    setState(() {
      _loadingPrestamos[cobradorId] = true;
      _errorPrestamos[cobradorId] = null;
    });

    try {
      final response = await ApiClient.get(
        '${Constants.apiUrl}/api/loans/cobrador/$cobradorId',
      );

      if (!mounted) return;

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _prestamosPorCobrador[cobradorId] = data;
          _loadingPrestamos[cobradorId] = false;
        });
      } else {
        setState(() {
          _errorPrestamos[cobradorId] = 'No se pudieron cargar los préstamos';
          _loadingPrestamos[cobradorId] = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorPrestamos[cobradorId] = 'Error de conexión';
        _loadingPrestamos[cobradorId] = false;
      });
    }
  }

  void _refrescarPrestamosDeCobrador(String cobradorId) {
    setState(() {
      _prestamosPorCobrador.remove(cobradorId);
      _errorPrestamos.remove(cobradorId);
    });
    _cargarPrestamosDeCobrador(cobradorId);
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'mora':
        return Colors.red;
      case 'pagado':
        return Colors.grey;
      case 'renovado':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'mora':
        return Icons.warning_amber_rounded;
      case 'pagado':
        return Icons.check_circle;
      case 'renovado':
        return Icons.autorenew;
      default:
        return Icons.receipt_long;
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
              const Text(
                'Acceso restringido',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
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
      appBar: AppBar(
        title: const Text(
          'Cobradores',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE8F5E9),
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      floatingActionButton: _esAdmin
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => abrirFormularioNuevoCobrador(
                context,
                _rutas,
                _cargarDatos,
              ),
              backgroundColor: const Color(0xFFA5D6A7),
              icon: const Icon(Icons.person_add),
              label: const Text(
                'Nuevo Cobrador',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cobradores.isEmpty
              ? RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'No hay cobradores registrados.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _cobradores.length,
                    itemBuilder: (context, index) {
                      final cobrador = _cobradores[index];
                      final cobradorId = cobrador['id'].toString();
                      final rutas = (cobrador['rutas'] as List?)
                              ?.map((r) => r['nombre'].toString())
                              .join(', ') ??
                          'Sin rutas';

                      final prestamos = _prestamosPorCobrador[cobradorId];
                      final loading = _loadingPrestamos[cobradorId] == true;
                      final error = _errorPrestamos[cobradorId];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[200],
                              child: Text(
                                cobrador['nombre'].toString().isNotEmpty
                                    ? cobrador['nombre']
                                        .toString()[0]
                                        .toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            title: Text(
                              cobrador['nombre'] ?? 'Sin nombre',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Row(
                              children: [
                                const Icon(Icons.route,
                                    size: 13, color: Colors.green),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    rutas,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            onExpansionChanged: (expanded) {
                              if (expanded) {
                                _cargarPrestamosDeCobrador(cobradorId);
                              }
                            },
                            children: [
                              const Divider(height: 1),
                              if (loading)
                                const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else if (error != null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Text(
                                        error,
                                        style:
                                            const TextStyle(color: Colors.red),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () =>
                                            _refrescarPrestamosDeCobrador(
                                                cobradorId),
                                        icon: const Icon(Icons.refresh,
                                            size: 16),
                                        label: const Text('Reintentar'),
                                      ),
                                    ],
                                  ),
                                )
                              else if (prestamos == null)
                                const SizedBox.shrink()
                              else if (prestamos.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Este cobrador no tiene préstamos.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Préstamos (${prestamos.length})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () =>
                                            _refrescarPrestamosDeCobrador(
                                                cobradorId),
                                        child: const Icon(
                                          Icons.refresh,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...prestamos.map((p) {
                                  final estado =
                                      (p['estado'] ?? 'activo').toString();
                                  final saldo = (p['saldo_pendiente'] as num?)
                                          ?.toDouble() ??
                                      0;
                                  final cuota =
                                      (p['cuota_diaria'] as num?)?.toDouble() ??
                                          0;

                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      _iconoEstado(estado),
                                      color: _colorEstado(estado),
                                      size: 20,
                                    ),
                                    title: Text(
                                      p['cliente_nombre'] ?? 'Sin cliente',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      'Ruta: ${p['ruta_nombre'] ?? 'Sin ruta'} • Estado: $estado',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Saldo: \$${saldo.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                        Text(
                                          '\$${cuota.toStringAsFixed(0)}/día',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

void abrirFormularioNuevoCobrador(
  BuildContext context,
  List rutas,
  Future<void> Function() onCreado,
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
              const Text(
                'Nuevo Cobrador',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nombreController,
                keyboardType: TextInputType.name,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]'),
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Nombre completo *',
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'Solo letras',
                ),
              ),
              const SizedBox(height: 12),
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
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  hintText: 'Mínimo 6 caracteres',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setModalState(
                      () => obscurePassword = !obscurePassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Rutas asignadas *',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Selecciona una o más rutas',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              rutas.isEmpty
                  ? const Text(
                      'No hay rutas disponibles',
                      style: TextStyle(color: Colors.grey),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: rutas.map((ruta) {
                        final id = int.parse(ruta['id'].toString());
                        final nombre = ruta['nombre'].toString();
                        final seleccionada = rutasSeleccionadas.contains(id);

                        return FilterChip(
                          label: Text(nombre),
                          selected: seleccionada,
                          selectedColor: const Color(0xFFA5D6A7),
                          checkmarkColor: Colors.green[800],
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                if (!rutasSeleccionadas.contains(id)) {
                                  rutasSeleccionadas.add(id);
                                }
                              } else {
                                rutasSeleccionadas.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 24),
              guardando
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: () async {
                        final nombre = nombreController.text.trim();
                        final email = emailController.text.trim();
                        final password = passwordController.text.trim();

                        if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Completa todos los campos obligatorios'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (password.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('La contraseña debe tener al menos 6 caracteres'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        if (rutasSeleccionadas.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Selecciona al menos una ruta'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setModalState(() => guardando = true);

                        bool exito = false;
                        try {
                          exito = await cobradorService.createCobrador(
                            nombre,
                            email,
                            password,
                            rutasSeleccionadas,
                          );
                        } catch (_) {
                          exito = false;
                        }

                        setModalState(() => guardando = false);

                        if (!context.mounted) return;

                        if (exito) {
                          Navigator.pop(context);
                          await onCreado();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Cobrador creado exitosamente'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ Error al crear cobrador. Verifica el correo o la contraseña.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'Crear Cobrador',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA5D6A7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
            ],
          ),
        ),
      ),
    ),
  );
}