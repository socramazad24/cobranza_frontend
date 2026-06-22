// lib/screens/clientes_screen.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/client_service.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen>
    with AutomaticKeepAliveClientMixin {
  final ClientService _service = ClientService();
  final TextEditingController _searchCtrl = TextEditingController();

  List _clientes = [];
  List _clientesFiltrados = [];
  List _cobradores = [];
  String? _cobradorSeleccionado;
  String _nombreCobrador = 'Todos';
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
    super.dispose();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final rol =
        prefs.getString('user_rol') ?? prefs.getString('userrol') ?? 'cobrador';

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
      if (mounted) {
        setState(() => _cobradores = data);
      }
    } catch (_) {}
  }

  Future<void> _cargarClientes({String? cobradorId}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _service.getClientes(cobradorId: cobradorId);

      if (!mounted) return;

      setState(() {
        _clientes = data;
        _clientesFiltrados = data;
        _isLoading = false;
      });

      _aplicarBusqueda(_searchCtrl.text);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
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
              final nombre = (c['nombre'] ?? '').toString().toLowerCase();
              final telefono = (c['telefono'] ?? '').toString().toLowerCase();
              final dir = (c['direccion'] ?? '').toString().toLowerCase();

              return nombre.contains(q) ||
                  telefono.contains(q) ||
                  dir.contains(q);
            }).toList();
    });
  }

  Future<void> _recargar() async {
    setState(() {
      _dataCargada = false;
      _clientes = [];
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

  void _toggleModoSeleccion() {
    setState(() {
      _modoSeleccion = !_modoSeleccion;
      _seleccionados = {};
    });
  }

  void _seleccionarTodos() {
    setState(() {
      if (_seleccionados.length == _clientesFiltrados.length) {
        _seleccionados = {};
      } else {
        _seleccionados =
            _clientesFiltrados.map<String>((c) => c['id'].toString()).toSet();
      }
    });
  }

  Future<void> _eliminarSeleccionados() async {
    if (_seleccionados.isEmpty) return;

    final seleccionadosList = _clientesFiltrados
        .where((c) => _seleccionados.contains(c['id'].toString()))
        .toList();

    final conPrestamos = seleccionadosList
        .where((c) => (c['prestamos_activos'] ?? 0) > 0)
        .length;

    final confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar clientes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se eliminarán ${_seleccionados.length} cliente(s) y todos sus datos asociados (préstamos, pagos, observaciones).',
            ),
            if (conPrestamos > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '⚠️ $conPrestamos cliente(s) tienen préstamos activos que se perderán.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                  ),
                ),
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
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete, color: Colors.white, size: 16),
            label: const Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final request = await _deleteWithBody(
        '${Constants.apiUrl}/api/clients',
        {'cliente_ids': _seleccionados.toList()},
        token,
      );

      if (request != null && request.statusCode == 200) {
        final eliminados = _seleccionados.length;

        setState(() {
          _modoSeleccion = false;
          _seleccionados = {};
        });

        await _recargar();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ $eliminados cliente(s) eliminado(s) correctamente',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        String mensaje = 'Error al eliminar clientes';

        try {
          final data = jsonDecode(request?.body ?? '{}');
          mensaje = data['error'] ?? mensaje;
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<http.Response?> _deleteWithBody(
    String url,
    Map body,
    String token,
  ) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClientWrapper();
      return await client.deleteWithBody(uri, body, token);
    } catch (_) {
      return null;
    }
  }

  void _mostrarFiltro() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtrar por Cobrador',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              tileColor:
                  _cobradorSeleccionado == null ? Colors.blue.withOpacity(0.08) : null,
              leading: CircleAvatar(
                backgroundColor:
                    _cobradorSeleccionado == null ? Colors.blue : Colors.grey[300],
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
                  _nombreCobrador = 'Todos';
                });
                _cargarClientes();
              },
            ),
            const Divider(height: 12),
            ..._cobradores.map((c) {
              final id = c['id'].toString();
              final nombre = c['nombre'].toString();
              final activo = _cobradorSeleccionado == id;

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                tileColor: activo ? Colors.blue.withOpacity(0.08) : null,
                leading: CircleAvatar(
                  backgroundColor: activo ? Colors.blue : Colors.grey[300],
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(nombre),
                trailing:
                    activo ? const Icon(Icons.check_circle, color: Colors.blue) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _cobradorSeleccionado = id;
                    _nombreCobrador = nombre;
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
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_esAdmin) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _modoSeleccion ? null : _mostrarFiltro,
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _toggleModoSeleccion,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _modoSeleccion ? Colors.red : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _modoSeleccion ? Icons.close : Icons.checklist,
                        color: _modoSeleccion ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_modoSeleccion)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _seleccionados.isEmpty
                          ? 'Toca los clientes para seleccionar'
                          : '${_seleccionados.length} seleccionado(s)',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _seleccionarTodos,
                    icon: Icon(
                      _seleccionados.length == _clientesFiltrados.length
                          ? Icons.deselect
                          : Icons.select_all,
                      size: 16,
                    ),
                    label: Text(
                      _seleccionados.length == _clientesFiltrados.length
                          ? 'Ninguno'
                          : 'Todos',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  if (_seleccionados.isNotEmpty)
                    IconButton(
                      onPressed: _eliminarSeleccionados,
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      tooltip: 'Eliminar seleccionados',
                    ),
                ],
              ),
            ),
          if (!_modoSeleccion)
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_clientesFiltrados.length} clientes',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _recargar,
              child: _clientesFiltrados.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_search,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchCtrl.text.isNotEmpty
                                      ? 'Sin resultados para\n"${_searchCtrl.text}"'
                                      : 'No hay clientes registrados',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
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

  Widget _buildClienteCard(Map cliente) {
    final nombre = cliente['nombre'] ?? 'Sin nombre';
    final telefono = cliente['telefono'] ?? '';
    final direccion = cliente['direccion'] ?? '';
    final cobradorNombre = cliente['cobrador_nombre'] ?? 'Sin cobrador';
    final rutaNombre = cliente['ruta_nombre'] ?? 'Sin ruta';
    final prestamosActivos = cliente['prestamos_activos'] ?? 0;
    final totalPrestamos = cliente['total_prestamos'] ?? 0;
    final saldo = (cliente['saldo_pendiente'] as num?)?.toDouble() ?? 0;
    final tieneMora = cliente['tiene_mora'] == true;
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
              _modoSeleccion
                  ? GestureDetector(
                      onTap: () => _toggleSeleccion(id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(top: 10, right: 12),
                        decoration: BoxDecoration(
                          color: seleccionado ? Colors.red : Colors.transparent,
                          border: Border.all(
                            color: seleccionado
                                ? Colors.red
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: seleccionado
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: colorEstado.withOpacity(0.15),
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: colorEstado,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorEstado.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            labelEstado,
                            style: TextStyle(
                              color: colorEstado,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (telefono.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.phone, size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            telefono,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    if (direccion.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                direccion,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    const Divider(height: 8),
                    Row(
                      children: [
                        _miniStat(
                          Icons.receipt_long,
                          '$totalPrestamos préstamos',
                          Colors.blue,
                        ),
                        if (saldo > 0) ...[
                          const SizedBox(width: 12),
                          _miniStat(
                            Icons.attach_money,
                            '\$${saldo.toStringAsFixed(0)}',
                            Colors.orange,
                          ),
                        ],
                      ],
                    ),
                    if (_esAdmin) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.motorcycle,
                            size: 13,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$cobradorNombre · $rutaNombre',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
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
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class HttpClientWrapper {
  Future<http.Response> deleteWithBody(
    Uri uri,
    Map body,
    String token,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('DELETE', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.body = jsonEncode(body);
      final streamed = await client.send(request);
      return await http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }
}