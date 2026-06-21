// lib/screens/clientes_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/client_service.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen>
    with AutomaticKeepAliveClientMixin {

  final ClientService        _service   = ClientService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<dynamic> _clientes           = [];
  List<dynamic> _clientesFiltrados  = [];
  List<dynamic> _cobradores         = [];
  String?       _cobradorSeleccionado;
  String        _nombreCobrador     = 'Todos';
  bool          _isLoading          = false;
  bool          _dataCargada        = false;
  bool          _esAdmin            = false;

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
    super.dispose();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final rol   = prefs.getString('user_rol') ?? 'cobrador';
    setState(() => _esAdmin = rol == 'admin');

    if (_esAdmin) await _cargarCobradores();
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
        _clientes          = data;
        _clientesFiltrados = data;
        _isLoading         = false;
      });
      _aplicarBusqueda(_searchCtrl.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading   = false;
        _dataCargada = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando clientes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _aplicarBusqueda(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _clientesFiltrados = q.isEmpty
          ? _clientes
          : _clientes.where((c) {
              final nombre   = (c['nombre']    ?? '').toString().toLowerCase();
              final telefono = (c['telefono']  ?? '').toString().toLowerCase();
              final dir      = (c['direccion'] ?? '').toString().toLowerCase();
              return nombre.contains(q) ||
                     telefono.contains(q) ||
                     dir.contains(q);
            }).toList();
    });
  }

  Future<void> _recargar() async {
    setState(() {
      _dataCargada = false;
      _clientes    = [];
    });
    await _cargarClientes(cobradorId: _cobradorSeleccionado);
  }

  void _mostrarFiltro() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtrar por Cobrador',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Todos
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              tileColor: _cobradorSeleccionado == null
                  ? Colors.blue.withOpacity(0.08)
                  : null,
              leading: CircleAvatar(
                backgroundColor: _cobradorSeleccionado == null
                    ? Colors.blue
                    : Colors.grey[300],
                child: const Icon(Icons.people, color: Colors.white, size: 18),
              ),
              title: const Text('Todos los clientes'),
              trailing: _cobradorSeleccionado == null
                  ? const Icon(Icons.check_circle, color: Colors.blue)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _cobradorSeleccionado = null;
                  _nombreCobrador       = 'Todos';
                });
                _cargarClientes();
              },
            ),
            const Divider(height: 12),

            // Cobradores
            ..._cobradores.map((c) {
              final id     = c['id'].toString();
              final nombre = c['nombre'].toString();
              final activo = _cobradorSeleccionado == id;

              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                tileColor: activo ? Colors.blue.withOpacity(0.08) : null,
                leading: CircleAvatar(
                  backgroundColor: activo ? Colors.blue : Colors.grey[300],
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(nombre),
                trailing: activo
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _cobradorSeleccionado = id;
                    _nombreCobrador       = nombre;
                  });
                  _cargarClientes(cobradorId: id);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFE3F2FD),
      child: Column(
        children: [

          // ── Barra búsqueda + filtro ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _aplicarBusqueda,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, teléfono...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _aplicarBusqueda('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                if (_esAdmin) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _mostrarFiltro,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _cobradorSeleccionado != null
                            ? Colors.blue
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.filter_list,
                        color: _cobradorSeleccionado != null
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Chip info filtro activo ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _esAdmin
                      ? (_cobradorSeleccionado == null
                          ? 'Todos los cobradores'
                          : 'Cobrador: $_nombreCobrador')
                      : 'Mis clientes',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_clientesFiltrados.length} clientes',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista ────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recargar,
              child: _clientesFiltrados.isEmpty
                  ? ListView(
                      // ListView para que RefreshIndicator funcione aunque esté vacío
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_search,
                                    size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  _searchCtrl.text.isNotEmpty
                                      ? 'Sin resultados para\n"${_searchCtrl.text}"'
                                      : 'No hay clientes registrados',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _clientesFiltrados.length,
                      itemBuilder: (context, index) =>
                          _buildClienteCard(_clientesFiltrados[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteCard(Map<String, dynamic> cliente) {
    final nombre           = cliente['nombre']            ?? 'Sin nombre';
    final telefono         = cliente['telefono']          ?? '';
    final direccion        = cliente['direccion']         ?? '';
    final cobradorNombre   = cliente['cobrador_nombre']   ?? 'Sin cobrador';
    final rutaNombre       = cliente['ruta_nombre']       ?? 'Sin ruta';
    final prestamosActivos = cliente['prestamos_activos'] ?? 0;
    final totalPrestamos   = cliente['total_prestamos']   ?? 0;
    final saldo = (cliente['saldo_pendiente'] as num?)?.toDouble() ?? 0;
    final tieneMora = cliente['tiene_mora'] == true;

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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: colorEstado.withOpacity(0.15),
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: TextStyle(
                    color: colorEstado,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Nombre + badge
                  Row(children: [
                    Expanded(
                      child: Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: colorEstado.withOpacity(0.4)),
                      ),
                      child: Text(labelEstado,
                          style: TextStyle(
                              color: colorEstado,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 4),

                  // Teléfono
                  if (telefono.isNotEmpty)
                    Row(children: [
                      Icon(Icons.phone, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(telefono,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ]),

                  // Dirección
                  if (direccion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(children: [
                        Icon(Icons.location_on,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(direccion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                        ),
                      ]),
                    ),

                  const SizedBox(height: 6),
                  const Divider(height: 8),

                  // Stats
                  Row(children: [
                    _miniStat(Icons.receipt_long,
                        '$totalPrestamos préstamos', Colors.blue),
                    if (saldo > 0) ...[
                      const SizedBox(width: 12),
                      _miniStat(Icons.attach_money,
                          '\$${saldo.toStringAsFixed(0)}', Colors.orange),
                    ],
                  ]),

                  // Cobrador — solo admin
                  if (_esAdmin) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.motorcycle,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text('$cobradorNombre · $rutaNombre',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 11)),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold)),
    ]);
  }
}