// lib/screens/clientes_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/client_service.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';
import '../providers/auth_provider.dart';
import '../widgets/search_filter_bar.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen>
    with AutomaticKeepAliveClientMixin {
  final ClientService _service = ClientService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // ── Datos ──
  List _todosLosClientes = [];
  List _clientesFiltrados = [];
  List _cobradores = [];

  // ── Filtros ──
  String? _cobradorSeleccionado;
  String _filtroEstado = 'todos'; // 'todos' | 'al_dia' | 'mora' | 'activos'
  String _orden = 'nombre_asc';

  // ── Estado UI ──
  bool _isLoading = false;
  bool _dataCargada = false;
  bool _esAdmin = false;
  bool _modoSeleccion = false;
  Set<String> _seleccionados = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataCargada) {
      _dataCargada = true;
      _inicializar();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final rol = await AuthProvider.getRol();
    if (!mounted) return;
    setState(() => _esAdmin = rol == 'admin');

    if (_esAdmin) {
      await _cargarCobradores();
    }
    await _cargarClientes();
  }

  Future<void> _cargarCobradores() async {
    try {
      final data = await _service.getCobradores();
      if (mounted) setState(() => _cobradores = data);
    } catch (_) {}
  }

  Future<void> _cargarClientes({String? cobradorId}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _service.getClientes(cobradorId: cobradorId);
      if (!mounted) return;

      setState(() {
        _todosLosClientes = data;
        _isLoading = false;
      });

      _aplicarFiltros();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _mostrarError('Error cargando clientes: $e');
    }
  }

  // ── APLICAR TODOS LOS FILTROS ──
  void _aplicarFiltros() {
    if (!mounted) return;

    final query = _searchCtrl.text.toLowerCase().trim();

    // 🔑 FIX Bug 3: empezar con copia limpia, no agregar al anterior
    List resultado = List.from(_todosLosClientes);

    // 1. Filtro de cobrador
    if (_cobradorSeleccionado != null) {
      resultado = resultado.where((c) {
        return (c['cobrador_id']?.toString() ?? '') == _cobradorSeleccionado;
      }).toList();
    }

    // 2. Filtro de estado
    switch (_filtroEstado) {
      case 'al_dia':
        resultado = resultado.where((c) {
          final prestamosActivos = c['prestamos_activos'] ?? 0;
          final enMora = c['tienemora'] == true;
          return prestamosActivos == 0 && !enMora;
        }).toList();
        break;
      case 'mora':
        resultado = resultado.where((c) => c['tienemora'] == true).toList();
        break;
      case 'activos':
        resultado = resultado.where((c) => (c['prestamos_activos'] ?? 0) > 0).toList();
        break;
      case 'todos':
      default:
        // Mostrar todos
        break;
    }

    // 3. Búsqueda por texto
    if (query.isNotEmpty) {
      resultado = resultado.where((c) {
        final nombre = (c['nombre'] ?? '').toString().toLowerCase();
        final telefono = (c['telefono'] ?? '').toString().toLowerCase();
        final dir = (c['direccion'] ?? '').toString().toLowerCase();
        return nombre.contains(query) ||
            telefono.contains(query) ||
            dir.contains(query);
      }).toList();
    }

    // 4. Ordenamiento
    switch (_orden) {
      case 'saldo_desc':
        resultado.sort((a, b) {
          final sa = (a['saldopendiente'] as num?)?.toDouble() ?? 0;
          final sb = (b['saldopendiente'] as num?)?.toDouble() ?? 0;
          return sb.compareTo(sa);
        });
        break;
      case 'mora':
        resultado.sort((a, b) {
          final ma = a['tienemora'] == true ? 1 : 0;
          final mb = b['tienemora'] == true ? 1 : 0;
          return mb.compareTo(ma);
        });
        break;
      case 'nombre_asc':
      default:
        resultado.sort((a, b) {
          final na = (a['nombre'] ?? '').toString();
          final nb = (b['nombre'] ?? '').toString();
          return na.toLowerCase().compareTo(nb.toLowerCase());
        });
    }

    setState(() {
      _clientesFiltrados = resultado;
    });
  }

  // ── ACCIONES ──
  Future<void> _recargar() async {
    setState(() {
      _dataCargada = false;
      _modoSeleccion = false;
      _seleccionados = {};
    });
    await _cargarClientes(cobradorId: _cobradorSeleccionado);
  }

  void _toggleSeleccion(String id) {
    setState(() {
      if (_seleccionados.contains(id)) {
        _seleccionados.remove(id);
      } else {
        _seleccionados.add(id);
      }
    });
  }

  // 🔑 FIX Bug 1: Función para SALIR del modo selección
  void _salirModoSeleccion() {
    setState(() {
      _modoSeleccion = false;
      _seleccionados = {};
    });
  }

  Future<void> _eliminarSeleccionados() async {
    if (_seleccionados.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar clientes'),
          ],
        ),
        content: Text(
          '¿Eliminar ${_seleccionados.length} cliente(s) y todos sus datos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final response = await ApiClient.deleteWithBody(
        '${Constants.apiUrl}/api/clients',
        {'clienteids': _seleccionados.toList()},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response?.statusCode == 200) {
        _salirModoSeleccion(); // 🔑 FIX: usar la función
        await _recargar();
        if (mounted) _mostrarExito('Clientes eliminados');
      } else {
        String mensaje = 'Error';
        try {
          final data = jsonDecode(response?.body ?? '{}');
          mensaje = data['error'] ?? mensaje;
        } catch (_) {}
        _mostrarError(mensaje);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _mostrarError('Error: $e');
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  // ── CONSTRUIR LISTA DE FILTROS ──
  List<FilterChipData> _getFiltrosEstado() {
    return [
      const FilterChipData(label: 'Al día', value: 'al_dia', color: Colors.green),
      const FilterChipData(label: 'En mora', value: 'mora', color: Colors.red),
      const FilterChipData(label: 'Con préstamos', value: 'activos', color: Colors.amber),
    ];
  }

  List<FilterChipData> _getFiltrosOrden() {
    return [
      const FilterChipData(label: '📝 Nombre', value: 'nombre_asc'),
      const FilterChipData(label: '💰 Mayor saldo', value: 'saldo_desc', color: Colors.amber),
      const FilterChipData(label: '🔥 Primero mora', value: 'mora', color: Colors.red),
    ];
  }

  // ── ESTADÍSTICAS RÁPIDAS ──
  Map<String, int> _getEstadisticas() {
    int enMora = 0;
    int alDia = 0;
    int conPrestamos = 0;
    for (final c in _todosLosClientes) {
      if (c['tienemora'] == true) enMora++;
      final prestamosActivos = c['prestamos_activos'] ?? 0;
      if (prestamosActivos > 0) {
        conPrestamos++;
        if (c['tienemora'] != true) {
          // tiene préstamos pero no en mora
        }
      } else if (c['tienemora'] != true) {
        alDia++;
      }
    }
    return {
      'enMora': enMora,
      'alDia': alDia,
      'conPrestamos': conPrestamos,
    };
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading && _todosLosClientes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Container(
          color: const Color(0xFFE3F2FD),
          child: Column(
            children: [
              // ── BARRA DE BÚSQUEDA + FILTROS ──
              SearchFilterBar(
                controller: _searchCtrl,
                hintText: 'Buscar cliente, teléfono, dirección...',
                onChanged: (_) => _aplicarFiltros(),
                onClear: _aplicarFiltros,
                selectedFilter: _filtroEstado,
                onFilterChanged: (val) {
                  setState(() => _filtroEstado = val ?? 'todos');
                  _aplicarFiltros();
                },
                filterChips: [
                  const FilterChipData(label: 'Todos', value: null),
                  ..._getFiltrosEstado(),
                ],
              ),

              // ── ESTADÍSTICAS RÁPIDAS (chips) ──
              _buildEstadisticasRapidas(),

              // ── FILTRO DE COBRADOR (solo admin) ──
              if (_esAdmin && _cobradores.isNotEmpty)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.motorcycle, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _cobradorSeleccionado,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos los cobradores'),
                              ),
                              ..._cobradores.map((c) {
                                return DropdownMenuItem<String?>(
                                  value: c['id'].toString(),
                                  child: Text(c['nombre']?.toString() ?? ''),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => _cobradorSeleccionado = val);
                              _aplicarFiltros();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── BARRA DE ESTADÍSTICAS + ORDEN ──
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${_clientesFiltrados.length} de ${_todosLosClientes.length} clientes',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      initialValue: _orden,
                      tooltip: 'Ordenar por',
                      onSelected: (val) {
                        setState(() => _orden = val);
                        _aplicarFiltros();
                      },
                      itemBuilder: (ctx) => _getFiltrosOrden().map((c) {
                        return PopupMenuItem<String>(
                          value: c.value,
                          child: Row(
                            children: [
                              Icon(_orden == c.value ? Icons.check : Icons.circle_outlined, size: 16),
                              const SizedBox(width: 8),
                              Text(c.label),
                            ],
                          ),
                        );
                      }).toList(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 2),
                          Text(
                            _getFiltrosOrden()
                                .firstWhere((c) => c.value == _orden, orElse: () => const FilterChipData(label: 'A-Z', value: 'nombre_asc'))
                                .label,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── BARRA DE MODO SELECCIÓN ──
              if (_modoSeleccion)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      // 🔑 FIX Bug 1: Botón para SALIR del modo selección
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                        onPressed: _salirModoSeleccion,
                        tooltip: 'Salir de modo selección',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _seleccionados.isEmpty
                              ? 'Toca los clientes para seleccionar'
                              : '${_seleccionados.length} seleccionado(s)',
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_seleccionados.length == _clientesFiltrados.length) {
                              _seleccionados = {};
                            } else {
                              _seleccionados = _clientesFiltrados.map<String>((c) => c['id'].toString()).toSet();
                            }
                          });
                        },
                        icon: Icon(
                          _seleccionados.length == _clientesFiltrados.length ? Icons.deselect : Icons.select_all,
                          size: 16,
                        ),
                        label: Text(
                          _seleccionados.length == _clientesFiltrados.length ? 'Ninguno' : 'Todos',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                      ),
                      if (_seleccionados.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _eliminarSeleccionados,
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          tooltip: 'Eliminar seleccionados',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),

              // ── LISTA DE CLIENTES ──
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _recargar,
                  child: _clientesFiltrados.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.4,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_search, size: 60, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchCtrl.text.isNotEmpty
                                          ? 'Sin resultados para "${_searchCtrl.text}"'
                                          : 'No hay clientes',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                          cacheExtent: 600,
                          itemCount: _clientesFiltrados.length,
                          itemBuilder: (context, index) =>
                              _buildClienteCard(_clientesFiltrados[index]),
                        ),
                ),
              ),
            ],
          ),
        ),

        // 🔑 FIX Bug 1: FAB para entrar/salir del modo selección
        // (solo si NO está en modo selección y NO hay datos para mostrar)
        if (!_modoSeleccion && _todosLosClientes.isNotEmpty && _esAdmin)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'clientes-select',
              onPressed: () {
                setState(() {
                  _modoSeleccion = true;
                  _seleccionados = {};
                });
              },
              backgroundColor: Colors.red.shade400,
              icon: const Icon(Icons.checklist, color: Colors.white),
              label: const Text(
                'Seleccionar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  // ── ESTADÍSTICAS RÁPIDAS ──
  Widget _buildEstadisticasRapidas() {
    final stats = _getEstadisticas();
    if (stats.values.every((v) => v == 0)) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          if (stats['enMora']! > 0)
            _statChip('🔥 ${stats['enMora']} en mora', Colors.red),
          if (stats['enMora']! > 0 && (stats['alDia']! > 0 || stats['conPrestamos']! > 0))
            const SizedBox(width: 8),
          if (stats['conPrestamos']! > 0)
            _statChip('💼 ${stats['conPrestamos']} activos', Colors.amber),
          if (stats['conPrestamos']! > 0 && stats['alDia']! > 0)
            const SizedBox(width: 8),
          if (stats['alDia']! > 0)
            _statChip('✅ ${stats['alDia']} al día', Colors.green),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildClienteCard(Map cliente) {
    final nombre = cliente['nombre'] ?? 'Sin nombre';
    final telefono = cliente['telefono'] ?? '';
    final direccion = cliente['direccion'] ?? '';
    final cobradorNombre = cliente['cobradornombre'] ?? 'Sin cobrador';
    final rutaNombre = cliente['rutanombre'] ?? 'Sin ruta';
    final prestamosActivos = cliente['prestamos_activos'] ?? 0;
    final totalPrestamos = cliente['totalprestamos'] ?? 0;
    final saldo = (cliente['saldopendiente'] as num?)?.toDouble() ?? 0;
    final tieneMora = cliente['tienemora'] == true;
    final id = cliente['id'].toString();
    final seleccionado = _seleccionados.contains(id);

    final Color colorEstado = tieneMora
        ? Colors.red
        : prestamosActivos > 0
            ? Colors.orange
            : Colors.green;

    final String labelEstado = tieneMora
        ? 'En mora'
        : prestamosActivos > 0
            ? 'Activo'
            : 'Al día';

    return GestureDetector(
      onLongPress: _esAdmin
          ? () {
              if (!_modoSeleccion) {
                setState(() => _modoSeleccion = true);
              }
              _toggleSeleccion(id);
            }
          : null,
      onTap: _modoSeleccion ? () => _toggleSeleccion(id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.red.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: seleccionado ? Colors.red.shade400 : Colors.transparent,
            width: seleccionado ? 1.5 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(seleccionado ? 0.03 : 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_modoSeleccion)
                GestureDetector(
                  onTap: () => _toggleSeleccion(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(top: 10, right: 12),
                    decoration: BoxDecoration(
                      color: seleccionado ? Colors.red : Colors.transparent,
                      border: Border.all(
                        color: seleccionado ? Colors.red : Colors.grey.shade400,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: seleccionado ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: colorEstado.withOpacity(0.15),
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorEstado.withOpacity(0.4)),
                          ),
                          child: Text(
                            labelEstado,
                            style: TextStyle(color: colorEstado, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (telefono.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.phone, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(telefono, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    if (direccion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                direccion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    const Divider(height: 8),
                    Row(
                      children: [
                        _miniStat(Icons.receipt_long, '$totalPrestamos préstamos', Colors.blue),
                        if (saldo > 0) ...[
                          const SizedBox(width: 12),
                          _miniStat(Icons.attach_money, '\$${saldo.toStringAsFixed(0)}', Colors.orange),
                        ],
                      ],
                    ),
                    if (_esAdmin) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.motorcycle, size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$cobradorNombre · $rutaNombre',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
