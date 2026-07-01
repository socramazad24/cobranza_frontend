import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../services/cobrador_service.dart';

class NuevoPrestamoScreen extends StatefulWidget {
  const NuevoPrestamoScreen({super.key});

  @override
  State<NuevoPrestamoScreen> createState() => _NuevoPrestamoScreenState();
}

class _NuevoPrestamoScreenState extends State<NuevoPrestamoScreen> {
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _montoController = TextEditingController();
  final _totalPagarController = TextEditingController();
  final _diasPlazoController = TextEditingController();

  static const double _montoMin = 100000;
  static const double _montoMax = 5000000;
  static const double _totalPagarMax = 8000000;
  static const int _diasPlazoMin = 7;
  static const int _diasPlazoMax = 60;

  double _monto = 0;
  double _totalPagar = 0;
  int _diasPlazo = 0;
  bool _isLoading = false;
  bool _esAdmin = false;
  bool _cargando = true;

  List _cobradores = [];
  String? _cobradorSeleccionadoId;
  String? _cobradorSeleccionadoNombre;

  List _rutasCobrador = [];
  int? _rutaSeleccionadaId;
  String? _rutaSeleccionadaNombre;

  String? _userId;

  double get _cuotaDiaria =>
      (_diasPlazo > 0 && _totalPagar > 0) ? _totalPagar / _diasPlazo : 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();

    // Lee directamente desde SharedPreferences — AuthService.login los guarda correctamente
    final rolGuardado = (prefs.getString('userrol') ?? '').trim().toLowerCase();
    _userId = prefs.getString('userid') ?? '';

    debugPrint('═══════════════════════════════════');
    debugPrint('NuevoPrestamoScreen._cargarDatos()');
    debugPrint('userrol en prefs: "$rolGuardado"');
    debugPrint('userid en prefs: "$_userId"');
    debugPrint('═══════════════════════════════════');

    final esAdmin = rolGuardado == 'admin';

    if (!mounted) return;
    setState(() {
      _esAdmin = esAdmin;
      _cargando = false;
      _cobradorSeleccionadoId = null;
      _cobradorSeleccionadoNombre = null;
      _rutasCobrador = [];
      _rutaSeleccionadaId = null;
      _rutaSeleccionadaNombre = null;
    });

    if (_esAdmin) {
      try {
        final cobradores = await CobradorService().getCobradores();
        if (!mounted) return;
        setState(() {
          _cobradores = cobradores;
        });
      } catch (e) {
        _snack('Error cargando cobradores', Colors.red);
      }
    } else if (_userId != null && _userId!.isNotEmpty) {
      await _cargarRutasDeCobrador(_userId!);
    }
  }

  Future<void> _cargarRutasDeCobrador(String cobradorId) async {
    try {
      final rutas = await CobradorService().getRutasDeCobrador(cobradorId);
      if (!mounted) return;
      setState(() {
        _rutasCobrador = rutas;
        _rutaSeleccionadaId = null;
        _rutaSeleccionadaNombre = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rutasCobrador = [];
        _rutaSeleccionadaId = null;
        _rutaSeleccionadaNombre = null;
      });
      _snack('Error cargando rutas del cobrador', Colors.red);
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwttoken');
  }

  void _snack(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: color),
    );
  }

  void _onMontoChange(String value) {
    setState(() => _monto = double.tryParse(value) ?? 0);
  }

  void _onTotalPagarChange(String value) {
    setState(() => _totalPagar = double.tryParse(value) ?? 0);
  }

  void _onDiasPlazoChange(String value) {
    setState(() => _diasPlazo = int.tryParse(value) ?? 0);
  }

  Future<void> _guardarPrestamo() async {
    if (_isLoading) return;

    final nombre = _nombreController.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final telefono = _telefonoController.text.trim();
    final direccion = _direccionController.text.trim();

    if (nombre.isEmpty) {
      _snack('El nombre del cliente es requerido', Colors.red);
      return;
    }
    if (nombre.length < 3) {
      _snack('El nombre debe tener al menos 3 caracteres', Colors.red);
      return;
    }
    if (telefono.isNotEmpty && (telefono.length < 7 || telefono.length > 15)) {
      _snack('El teléfono debe tener entre 7 y 15 dígitos', Colors.red);
      return;
    }
    if (_monto < _montoMin || _monto > _montoMax) {
      _snack(
        'El monto debe estar entre \$${_montoMin.toStringAsFixed(0)} y \$${_montoMax.toStringAsFixed(0)}',
        Colors.red,
      );
      return;
    }
    if (_totalPagar <= 0) {
      _snack('Escribe la cantidad total a pagar', Colors.red);
      return;
    }
    if (_totalPagar <= _monto) {
      _snack('La cantidad a pagar debe ser mayor que el monto prestado', Colors.red);
      return;
    }
    if (_diasPlazo < _diasPlazoMin) {
      _snack('El plazo mínimo es $_diasPlazoMin días', Colors.red);
      return;
    }
    if (_totalPagar > _totalPagarMax) {
      _snack(
        'El total a pagar no puede superar \$${(_totalPagarMax / 1000).toStringAsFixed(0)}K',
        Colors.red,
      );
      return;
    }
    if (_diasPlazo > _diasPlazoMax) {
      _snack('El plazo máximo es $_diasPlazoMax días', Colors.red);
      return;
    }
    if (_esAdmin && _cobradorSeleccionadoId == null) {
      _snack('Selecciona un cobrador responsable', Colors.red);
      return;
    }
    if (!_esAdmin && (_userId == null || _userId!.isEmpty)) {
      _snack('No se pudo identificar el cobrador actual', Colors.red);
      return;
    }
    if (_rutaSeleccionadaId == null) {
      _snack('Selecciona una ruta', Colors.red);
      return;
    }

    final cobradorIdFinal = _esAdmin ? _cobradorSeleccionadoId : _userId;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          '¿Confirmar préstamo?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmFila('Cliente', nombre),
            _confirmFila('Monto prestado', '\$${_monto.toStringAsFixed(0)}'),
            _confirmFila('Total a pagar', '\$${_totalPagar.toStringAsFixed(0)}'),
            _confirmFila('Plazo', '$_diasPlazo días'),
            _confirmFila('Cuota diaria', '\$${_cuotaDiaria.toStringAsFixed(0)}/día'),
            if (_esAdmin && _cobradorSeleccionadoNombre != null)
              _confirmFila('Cobrador', _cobradorSeleccionadoNombre!),
            if (!_esAdmin)
              const Text(
                'Este préstamo se asignará automáticamente a tu usuario.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            if (_rutaSeleccionadaNombre != null)
              _confirmFila('Ruta', _rutaSeleccionadaNombre!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _snack('Sesión expirada. Inicia sesión nuevamente', Colors.red);
        return;
      }

      final body = {
        'clientenombre': nombre,
        'clientetelefono': telefono,
        'clientedireccion': direccion,
        'montoprestado': _monto,
        'montototal': _totalPagar,
        'diasplazo': _diasPlazo,
        'cobradorid': cobradorIdFinal,
        'rutaid': _rutaSeleccionadaId,
        'modointeres': 'manual',
      };

      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/api/loans'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 201) {
        _snack('✅ Préstamo creado exitosamente', Colors.green);
        Navigator.pop(context, true);
      } else {
        String error = 'Error desconocido';
        try {
          final decoded = jsonDecode(response.body);
          error = decoded['error']?.toString() ?? error;
        } catch (_) {}
        _snack('❌ $error', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack('❌ Sin conexión al servidor', Colors.red);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _montoController.dispose();
    _totalPagarController.dispose();
    _diasPlazoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Préstamo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFF9C4),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFFFFDE7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Datos del Cliente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _nombreController,
              keyboardType: TextInputType.name,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]'),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Nombre completo *',
                prefixIcon: Icon(Icons.person),
                hintText: 'Solo letras',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: Icon(Icons.phone),
                hintText: 'Solo números',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _direccionController,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 20),

            // ── SELECTOR DE COBRADOR (solo admin) ──────────────────────
            if (_esAdmin) ...[
              const Text('Cobrador Responsable',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Seleccionar cobrador *',
                  prefixIcon: Icon(Icons.motorcycle),
                ),
                value: _cobradorSeleccionadoId,
                items: _cobradores
                    .map<DropdownMenuItem<String>>(
                      (c) => DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text(c['nombre']),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  setState(() {
                    _cobradorSeleccionadoId = value;
                    _cobradorSeleccionadoNombre = value == null
                        ? null
                        : _cobradores.firstWhere(
                            (c) => c['id'].toString() == value,
                          )['nombre'];
                    _rutaSeleccionadaId = null;
                    _rutaSeleccionadaNombre = null;
                    _rutasCobrador = [];
                  });
                  if (value != null) {
                    await _cargarRutasDeCobrador(value);
                  }
                },
              ),
              const SizedBox(height: 20),
            ],

            // ── AVISO COBRADOR (solo si NO es admin) ───────────────────
            if (!_esAdmin) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.person_pin_circle, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este préstamo quedará asignado automáticamente a tu usuario.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── RUTA ───────────────────────────────────────────────────
            const Text('Ruta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _rutasCobrador.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Text(
                      _esAdmin
                          ? 'Selecciona un cobrador para ver sus rutas'
                          : 'No tienes rutas asignadas. Contacta al administrador.',
                      style: TextStyle(color: Colors.orange[800]),
                      textAlign: TextAlign.center,
                    ),
                  )
                : DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Seleccionar ruta *',
                      prefixIcon: Icon(Icons.map),
                    ),
                    value: _rutaSeleccionadaId,
                    items: _rutasCobrador
                        .map<DropdownMenuItem<int>>(
                          (r) => DropdownMenuItem<int>(
                            value: r['id'] as int,
                            child: Text(r['nombre']),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _rutaSeleccionadaId = value;
                      _rutaSeleccionadaNombre = value == null
                          ? null
                          : _rutasCobrador.firstWhere(
                              (r) => r['id'] == value,
                            )['nombre'];
                    }),
                  ),
            const SizedBox(height: 20),

            // ── MONTO ──────────────────────────────────────────────────
            const Text('Monto a Prestar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Monto *',
                hintText: 'Máx: ${_montoMax.toStringAsFixed(0)}',
                prefixText: '\$ ',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              onChanged: _onMontoChange,
            ),
            const SizedBox(height: 20),

            // ── TOTAL A PAGAR ──────────────────────────────────────────
            const Text('Total a Pagar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _totalPagarController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Cantidad total a pagar *',
                hintText: 'Máx: ${_totalPagarMax.toStringAsFixed(0)}',
                prefixText: '\$ ',
                prefixIcon: const Icon(Icons.price_check),
              ),
              onChanged: _onTotalPagarChange,
            ),
            const SizedBox(height: 20),

            // ── PLAZO ──────────────────────────────────────────────────
            const Text('Plazo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _diasPlazoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Días de plazo *',
                hintText: 'Mín: $_diasPlazoMin | Máx: $_diasPlazoMax',
                prefixIcon: const Icon(Icons.calendar_today),
              ),
              onChanged: _onDiasPlazoChange,
            ),
            const SizedBox(height: 20),

            // ── RESUMEN ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.amber),
              ),
              child: Column(
                children: [
                  const Text('Resumen del Préstamo',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _resumenFila('Capital prestado:',
                      '\$${_monto.toStringAsFixed(0)}'),
                  _resumenFila('Total a pagar:',
                      '\$${_totalPagar.toStringAsFixed(0)}',
                      bold: true),
                  _resumenFila(
                      'Cuota diaria:',
                      '\$${_cuotaDiaria.toStringAsFixed(0)}/día',
                      bold: true,
                      color: Colors.green),
                  _resumenFila('Plazo:', '$_diasPlazo días'),
                  if (_monto > _montoMax ||
                      _totalPagar > _totalPagarMax ||
                      _diasPlazo > _diasPlazoMax ||
                      (_diasPlazo > 0 && _diasPlazo < _diasPlazoMin))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '⚠️ Algunos valores no cumplen las reglas permitidas',
                                style:
                                    TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_esAdmin && _cobradorSeleccionadoNombre != null)
                    _resumenFila('Cobrador:', _cobradorSeleccionadoNombre!),
                  if (!_esAdmin) _resumenFila('Asignado a:', 'Mi usuario'),
                  if (_rutaSeleccionadaNombre != null)
                    _resumenFila('Ruta:', _rutaSeleccionadaNombre!),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _guardarPrestamo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD54F),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Crear Préstamo',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _resumenFila(String label, String valor,
      {bool bold = false, Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}