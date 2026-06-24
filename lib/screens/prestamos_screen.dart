import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';
import '../services/observacion_service.dart';
import '../services/cobrador_service.dart';
import 'nuevo_prestamo_screen.dart';

class PrestamosScreen extends StatefulWidget {
  const PrestamosScreen({super.key});

  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> {
  List _prestamos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPrestamos();
  }

  Future<void> _cargarPrestamos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final response =
        await ApiClient.get('${Constants.apiUrl}/api/payments/active');

    if (response != null && response.statusCode == 200 && mounted) {
      setState(() => _prestamos = jsonDecode(response.body));
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBE9E7),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final resultado = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const NuevoPrestamoScreen(),
            ),
          );

          if (resultado == true && mounted) {
            await _cargarPrestamos();
          }
        },
        backgroundColor: const Color(0xFFFFAB91),
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo Préstamo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prestamos.isEmpty
              ? const Center(
                  child: Text(
                    'No hay préstamos activos.\nPresiona + para crear uno.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _prestamos.length,
                  itemBuilder: (context, index) {
                    final p = _prestamos[index];
                    final cliente = p['clientes'] ?? {};
                    final ruta = cliente['rutas'];
                    final cobrador =
                        p['usuarios']?['nombre'] ?? 'Sin cobrador';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange[100],
                          child: const Icon(
                            Icons.person,
                            color: Colors.orange,
                          ),
                        ),
                        title: Text(
                          cliente['nombre'] ?? 'Sin cliente',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo: \$${double.parse(p['saldo_pendiente'].toString()).toStringAsFixed(0)}',
                            ),
                            if (ruta != null)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.map,
                                    size: 12,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    ruta['nombre'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cobrador,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Text(
                          '\$${double.parse(p['cuota_diaria'].toString()).toStringAsFixed(0)}/día',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () async {
                          final resultado = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetallePrestamoScreen(prestamo: p),
                            ),
                          );

                          if (resultado == true && mounted) {
                            await _cargarPrestamos();
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

class DetallePrestamoScreen extends StatefulWidget {
  final Map prestamo;
  const DetallePrestamoScreen({super.key, required this.prestamo});

  @override
  State<DetallePrestamoScreen> createState() => _DetallePrestamoScreenState();
}

class _DetallePrestamoScreenState extends State<DetallePrestamoScreen> {
  List _historial = [];
  bool _isLoading = true;
  bool _esAdmin = false;
  final TextEditingController _montoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    final rol =
        prefs.getString('user_rol') ?? prefs.getString('userrol') ?? 'cobrador';

    if (mounted) {
      setState(() => _esAdmin = rol == 'admin');
      await _cargarHistorial();
    }
  }

  Future<void> _cargarHistorial() async {
    setState(() => _isLoading = true);

    final response = await ApiClient.get(
      '${Constants.apiUrl}/api/payments/history/${widget.prestamo['id']}',
    );

    if (response != null && response.statusCode == 200 && mounted) {
      setState(() => _historial = jsonDecode(response.body));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _editarPrestamo() {
    final p = widget.prestamo;
    final fechaFinActual = DateTime.parse(p['fecha_fin']);
    final montoActual = double.parse(p['monto_prestado'].toString());

    late TextEditingController montoCtrl;
    late TextEditingController saldoCtrl;
    late TextEditingController diasCtrl;
    late TextEditingController fechaCtrl;
    DateTime nuevaFechaFin = fechaFinActual;
    String? errorSaldo;
    bool saldoValido = true;

    montoCtrl = TextEditingController(text: montoActual.toStringAsFixed(0));
    saldoCtrl = TextEditingController(
      text: double.parse(p['saldo_pendiente'].toString()).toStringAsFixed(0),
    );
    diasCtrl = TextEditingController();
    fechaCtrl = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(fechaFinActual),
    );

    void actualizarValidacion() {
      final monto = double.tryParse(montoCtrl.text) ?? 0;
      final saldo = double.tryParse(saldoCtrl.text) ?? 0;
      saldoValido = saldo > 0 && saldo <= monto * 1.20;
      errorSaldo = saldoValido
          ? null
          : saldo > monto * 1.20
              ? 'Máximo 20% de intereses (${(monto * 1.20).toStringAsFixed(0)})'
              : 'Saldo debe ser > 0';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: const [
                    Icon(Icons.edit, color: Colors.deepPurple),
                    SizedBox(width: 8),
                    Text(
                      'Editar Préstamo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Cliente: ${p['clientes']?['nombre'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const Divider(height: 24),
                const Text(
                  'Monto Prestado',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: montoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    actualizarValidacion();
                    setStateModal(() {});
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Saldo Pendiente',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: saldoCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    border: const OutlineInputBorder(),
                    errorText: errorSaldo,
                    helperText: 'Máx. 120% del monto prestado',
                    helperStyle: const TextStyle(color: Colors.grey),
                  ),
                  onChanged: (_) {
                    actualizarValidacion();
                    setStateModal(() {});
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ampliar Plazo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: diasCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          suffixText: 'días',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final dias = int.tryParse(val) ?? 0;
                          nuevaFechaFin = fechaFinActual.add(Duration(days: dias));
                          fechaCtrl.text =
                              DateFormat('dd/MM/yyyy').format(nuevaFechaFin);
                          setStateModal(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: nuevaFechaFin,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            final diff =
                                picked.difference(fechaFinActual).inDays;
                            nuevaFechaFin = picked;
                            diasCtrl.text = diff > 0 ? diff.toString() : '0';
                            fechaCtrl.text =
                                DateFormat('dd/MM/yyyy').format(picked);
                            setStateModal(() {});
                          }
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            controller: fechaCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(
                              suffixIcon: Icon(Icons.calendar_today),
                              labelText: 'Nueva fecha fin',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Actual: ${DateFormat('dd MMM yyyy').format(fechaFinActual)}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: saldoValido
                      ? () => _guardarEdicion(
                            montoCtrl,
                            saldoCtrl,
                            nuevaFechaFin,
                          )
                      : null,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Guardar Cambios',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
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

  Future<void> _guardarEdicion(
    TextEditingController montoCtrl,
    TextEditingController saldoCtrl,
    DateTime nuevaFechaFin,
  ) async {
    final nuevoMonto = double.tryParse(montoCtrl.text) ?? 0;
    final nuevoSaldo = double.tryParse(saldoCtrl.text) ?? 0;
    final p = widget.prestamo;

    final confirmar = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          '¿Confirmar cambios?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Monto prestado', '\$${nuevoMonto.toStringAsFixed(0)}'),
            _confirmRow('Saldo pendiente', '\$${nuevoSaldo.toStringAsFixed(0)}'),
            _confirmRow(
              'Nueva fecha fin',
              DateFormat('dd MMM yyyy').format(nuevaFechaFin),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    Navigator.pop(context);

    final response = await ApiClient.put(
      '${Constants.apiUrl}/api/loans/${p['id']}',
      {
        'monto_prestado': nuevoMonto,
        'saldo_pendiente': nuevoSaldo,
        'fecha_fin': DateFormat('yyyy-MM-dd').format(nuevaFechaFin),
      },
    );

    if (response?.statusCode == 200 && mounted) {
      setState(() {
        p['monto_prestado'] = nuevoMonto.toString();
        p['saldo_pendiente'] = nuevoSaldo.toString();
        p['fecha_fin'] = DateFormat('yyyy-MM-dd').format(nuevaFechaFin);
      });
      _showSnack('✅ Préstamo actualizado', Colors.green);
    } else {
      _showSnack(
        '❌ ${jsonDecode(response?.body ?? '{}')['error'] ?? 'Error desconocido'}',
        Colors.red,
      );
    }
  }

  void _renovarDeuda() {
    final diasCtrl = TextEditingController(text: '30');
    final saldoActual =
        double.parse(widget.prestamo['saldo_pendiente'].toString());

    showModalBottomSheet(
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
            Row(
              children: const [
                Icon(Icons.refresh, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Renovar Deuda',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saldo actual: \$${saldoActual.toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            const Text(
              'El backend actual renovará el préstamo usando el saldo pendiente y calculará el nuevo total automáticamente.',
              style: TextStyle(color: Colors.grey),
            ),
            const Divider(height: 24),
            TextField(
              controller: diasCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Días de plazo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _confirmarRenovacion(diasCtrl),
              icon: const Icon(Icons.save),
              label: const Text(
                'Renovar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarRenovacion(
    TextEditingController diasCtrl,
  ) async {
    final diasPlazo = int.tryParse(diasCtrl.text.trim()) ?? 0;

    if (diasPlazo <= 0) {
      _showSnack('❌ Días inválidos', Colors.red);
      return;
    }

    Navigator.pop(context);

    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/payments/renew',
      {
        'prestamo_id': widget.prestamo['id'],
        'dias_plazo': diasPlazo,
      },
    );

    if (response?.statusCode == 201 && mounted) {
      _showSnack('✅ Deuda renovada exitosamente', Colors.green);
      Navigator.pop(context, true);
    } else {
      String mensaje = '❌ Error al renovar';
      try {
        final data = jsonDecode(response?.body ?? '{}');
        mensaje = data['error'] ?? mensaje;
      } catch (_) {}
      _showSnack(mensaje, Colors.red);
    }
  }

  Widget _confirmRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  void _showSnack(String mensaje, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _registrarPago() async {
    final prestamoId = widget.prestamo['id'];
    final monto = double.tryParse(_montoController.text.trim()) ?? 0;
    final saldoActual =
        double.tryParse(widget.prestamo['saldo_pendiente'].toString()) ?? 0;

    if (prestamoId == null) {
      _showSnack('❌ No se encontró el ID del préstamo', Colors.red);
      return;
    }

    if (monto <= 0) {
      _showSnack('Monto inválido', Colors.red);
      return;
    }

    if (monto > saldoActual) {
      _showSnack(
        'El monto \$${monto.toStringAsFixed(0)} supera el saldo pendiente de \$${saldoActual.toStringAsFixed(0)}',
        Colors.red,
      );
      return;
    }

    final confirmado = await _confirmDialog(
      '¿Confirmar pago?',
      'Abono de \$${monto.toStringAsFixed(0)}',
    );

    if (confirmado != true) return;

    final body = {
      'prestamo_id': prestamoId,
      'monto_pagado': monto,
    };

    final response = await ApiClient.post(
      '${Constants.apiUrl}/api/payments/pay',
      body,
    );

    if (!mounted) return;

    if (response != null && response.statusCode == 201) {
      final data = jsonDecode(response.body);

      setState(() {
        widget.prestamo['saldo_pendiente'] =
            (data['saldorestante'] as num).toDouble();
        widget.prestamo['estado'] = data['estado'];
      });

      _montoController.clear();
      await _cargarHistorial();

      _showSnack(
        data['estado'] == 'pagado'
            ? '✅ ¡Préstamo pagado!'
            : '✅ Pago registrado',
        Colors.green,
      );

      if (data['estado'] == 'pagado') {
        Navigator.pop(context, true);
      }
    } else {
      String mensaje = '❌ Error al registrar pago';
      try {
        final data = jsonDecode(response?.body ?? '{}');
        mensaje = data['error'] ?? mensaje;
      } catch (_) {}
      _showSnack(mensaje, Colors.red);
    }
  }

  Future<dynamic> _confirmDialog(String titulo, String contenido) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(contenido),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _editarRutasCobrador() async {
    final cobradorId = widget.prestamo['cobrador_id']?.toString();
    if (cobradorId == null) {
      _showSnack('Sin cobrador asignado', Colors.red);
      return;
    }

    final cobradorService = CobradorService();

    final todasLasRutas = await cobradorService.getRutas();
    final rutasActuales = await cobradorService.getRutasDeCobrador(cobradorId);

    List seleccionadas =
        rutasActuales.map((r) => int.parse(r['id'].toString())).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => Padding(
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
              const Text(
                'Editar Rutas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Cobrador: ${widget.prestamo['usuarios']?['nombre'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              todasLasRutas.isEmpty
                  ? const Text(
                      'Sin rutas',
                      style: TextStyle(color: Colors.grey),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: todasLasRutas.map((r) {
                        final rutaId = int.parse(r['id'].toString());
                        return FilterChip(
                          label: Text(r['nombre']),
                          selected: seleccionadas.contains(rutaId),
                          selectedColor: const Color(0xFFA5D6A7),
                          onSelected: (v) => setStateModal(() {
                            if (v) {
                              if (!seleccionadas.contains(rutaId)) {
                                seleccionadas.add(rutaId);
                              }
                            } else {
                              seleccionadas.remove(rutaId);
                            }
                          }),
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: seleccionadas.isEmpty
                    ? null
                    : () async {
                        final response = await ApiClient.put(
                          '${Constants.apiUrl}/api/rutas/cobrador/$cobradorId',
                          {'ruta_ids': seleccionadas},
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        _showSnack(
                          response?.statusCode == 200
                              ? '✅ Rutas actualizadas'
                              : '❌ Error',
                          response?.statusCode == 200
                              ? Colors.green
                              : Colors.red,
                        );
                      },
                icon: const Icon(Icons.save),
                label: const Text(
                  'Guardar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF81D4FA),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirObservacion() {
    final ctrl = TextEditingController();

    showModalBottomSheet(
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
          children: [
            const Text(
              'Reportar Observación',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe el error...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setStateModal) {
                ctrl.addListener(() {
                  if (context.mounted) setStateModal(() {});
                });

                return ElevatedButton.icon(
                  onPressed: ctrl.text.trim().isEmpty
                      ? null
                      : () async {
                          final success =
                              await ObservacionService().createObservacion(
                            'prestamo',
                            widget.prestamo['id'] as int,
                            ctrl.text.trim(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _showSnack(
                            success ? '✅ Enviado' : '❌ Error',
                            success ? Colors.green : Colors.red,
                          );
                        },
                  icon: const Icon(Icons.send),
                  label: const Text(
                    'Enviar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prestamo;
    final cliente = p['clientes'] ?? {};
    final ruta = cliente['rutas'];
    final cobradorNombre = p['usuarios']?['nombre'] ?? 'Sin cobrador';
    final fechaInicio =
        DateFormat('dd MMM yyyy').format(DateTime.parse(p['fecha_inicio']));
    final fechaFin =
        DateFormat('dd MMM yyyy').format(DateTime.parse(p['fecha_fin']));
    final saldoPendiente = double.parse(p['saldo_pendiente'].toString());

    return Scaffold(
      backgroundColor: const Color(0xFFFBE9E7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                  label: const Text(
                    'Regresar',
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_esAdmin)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: _editarPrestamo,
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.deepPurple,
                                size: 18,
                              ),
                              label: const Text(
                                'Editar préstamo',
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _editarRutasCobrador,
                              icon: const Icon(
                                Icons.edit_road,
                                color: Colors.blue,
                                size: 18,
                              ),
                              label: const Text(
                                'Rutas cobrador',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const Text(
                        'Nombre del Cliente',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        cliente['nombre'] ?? 'Sin cliente',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (cliente['telefono'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '📞 ${cliente['telefono']}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (ruta != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.map, size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              ruta['nombre'] ?? '',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cobrador: $cobradorNombre',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Monto Prestado',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '\$${double.parse(p['monto_prestado'].toString()).toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fecha Inicio',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                fechaInicio,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Fecha Fin',
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                fechaFin,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Saldo Pendiente',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '\$${saldoPendiente.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Registrar Abono',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _montoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          hintText: 'Monto del abono',
                          helperText:
                              'Máx: \$${saldoPendiente.toStringAsFixed(0)}',
                          helperStyle: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _registrarPago,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF81C784),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Registrar Pago',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _renovarDeuda,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Renovar Deuda',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _abrirObservacion,
                        icon: const Icon(
                          Icons.report_problem_outlined,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          'Reportar error',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Historial de Pagos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _historial.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text(
                            'Sin pagos aún',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _historial.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final pago = _historial[i];
                              return ListTile(
                                leading: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                title: const Text('Abono registrado'),
                                subtitle: Text(
                                  DateFormat('dd MMM yyyy – hh:mm a').format(
                                    DateTime.parse(
                                      pago['fecha_pago'],
                                    ).toLocal(),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  '\$${double.parse(pago['monto_pagado'].toString()).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ],
          ),
        ),
      ),
    );
  }
}