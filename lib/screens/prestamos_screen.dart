// lib/screens/prestamos_screen.dart
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


// ─────────────────────────────────────────────────
// LISTA DE PRÉSTAMOS ACTIVOS
// ─────────────────────────────────────────────────
class PrestamosScreen extends StatefulWidget {
  const PrestamosScreen({super.key});

  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> {
  List<dynamic> _prestamos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPrestamos();
  }

  Future<void> _cargarPrestamos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // ✅ ApiClient — sin token manual
    final response =
        await ApiClient.get('${Constants.apiUrl}/api/payments/active');

    if (response != null && response.statusCode == 200 && mounted) {
      setState(() => _prestamos = jsonDecode(response.body));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBE9E7),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NuevoPrestamoScreen()),
        ).then((_) => _cargarPrestamos()),
        backgroundColor: const Color(0xFFFFAB91),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Préstamo',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                    final p        = _prestamos[index];
                    final cliente  = p['clientes'];
                    final ruta     = cliente['rutas'];
                    final cobrador = p['usuarios']?['nombre'] ?? 'Sin cobrador';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange[100],
                          child: const Icon(Icons.person, color: Colors.orange),
                        ),
                        title: Text(cliente['nombre'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo: \$${double.parse(p['saldo_pendiente'].toString()).toStringAsFixed(0)}',
                            ),
                            if (ruta != null)
                              Row(children: [
                                const Icon(Icons.map,
                                    size: 12, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(ruta['nombre'],
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.blue)),
                              ]),
                            Row(children: [
                              const Icon(Icons.person_outline,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(cobrador,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ]),
                          ],
                        ),
                        trailing: Text(
                          '\$${double.parse(p['cuota_diaria'].toString()).toStringAsFixed(0)}/día',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetallePrestamoScreen(prestamo: p),
                          ),
                        ).then((_) => _cargarPrestamos()),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─────────────────────────────────────────────────
// DETALLE + HISTORIAL DE PAGOS (OPTIMIZADO)
// ─────────────────────────────────────────────────
class DetallePrestamoScreen extends StatefulWidget {
  final Map<String, dynamic> prestamo;
  const DetallePrestamoScreen({super.key, required this.prestamo});

  @override
  State<DetallePrestamoScreen> createState() => _DetallePrestamoScreenState();
}

class _DetallePrestamoScreenState extends State<DetallePrestamoScreen> {
  List<dynamic> _historial = [];
  bool _isLoading = true;
  bool _esAdmin = false;
  final TextEditingController _montoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final rol = (await SharedPreferences.getInstance())
        .getString('user_rol') ?? 'cobrador';
    if (mounted) {
      setState(() => _esAdmin = rol == 'admin');
      await _cargarHistorial();
    }
  }

  Future<void> _cargarHistorial() async {
    setState(() => _isLoading = true);
    final response = await ApiClient.get(
        '${Constants.apiUrl}/api/payments/history/${widget.prestamo['id']}');
    if (response != null && response.statusCode == 200 && mounted) {
      setState(() => _historial = jsonDecode(response.body));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // ── ✅ EDITAR PRÉSTAMO (ADMIN) ──────────────────────────────
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
    saldoCtrl = TextEditingController(text: double.parse(p['saldo_pendiente'].toString()).toStringAsFixed(0));
    diasCtrl = TextEditingController();
    fechaCtrl = TextEditingController(text: DateFormat('dd/MM/yyyy').format(fechaFinActual));

    void actualizarValidacion() {
      final monto = double.tryParse(montoCtrl.text) ?? 0;
      final saldo = double.tryParse(saldoCtrl.text) ?? 0;
      saldoValido = saldo > 0 && saldo <= monto * 1.20;
      errorSaldo = saldoValido ? null : saldo > monto * 1.20 
          ? 'Máximo 20% de intereses (${(monto*1.20).toStringAsFixed(0)})'
          : 'Saldo debe ser > 0';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(children: [
                  Icon(Icons.edit, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('Editar Préstamo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ]),
                Text('Cliente: ${p['clientes']?['nombre'] ?? 'N/A'}', style: TextStyle(color: Colors.grey)),
                Divider(height: 24),

                // Monto prestado
                Text('Monto Prestado', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                TextField(controller: montoCtrl, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(prefixText: '\$ ', border: OutlineInputBorder()),
                  onChanged: (_) => {actualizarValidacion(), setState(() {})}),
                SizedBox(height: 16),

                // Saldo pendiente + VALIDACIÓN VISIBLE ✅
                Text('Saldo Pendiente', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                TextField(controller: saldoCtrl, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    errorText: errorSaldo,
                    helperText: 'Máx. 120% del monto prestado',
                    helperStyle: TextStyle(color: Colors.grey),
                  ),
                  onChanged: (_) => {actualizarValidacion(), setState(() {})}),
                SizedBox(height: 16),

                // Ampliar plazo
                Text('Ampliar Plazo', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextField(
                    controller: diasCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(suffixText: 'días', border: OutlineInputBorder()),
                    onChanged: (val) {
                      final dias = int.tryParse(val) ?? 0;
                      nuevaFechaFin = fechaFinActual.add(Duration(days: dias));
                      fechaCtrl.text = DateFormat('dd/MM/yyyy').format(nuevaFechaFin);
                      setState(() {});
                    },
                  )),
                  SizedBox(width: 12),
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(context: ctx, initialDate: nuevaFechaFin,
                        firstDate: DateTime.now(), lastDate: DateTime(2100));
                      if (picked != null) {
                        final diff = picked.difference(fechaFinActual).inDays;
                        nuevaFechaFin = picked;
                        diasCtrl.text = diff > 0 ? diff.toString() : '0';
                        fechaCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
                        setState(() {});
                      }
                    },
                    child: AbsorbPointer(child: TextField(
                      controller: fechaCtrl, readOnly: true,
                      decoration: InputDecoration(suffixIcon: Icon(Icons.calendar_today),
                        labelText: 'Nueva fecha fin', border: OutlineInputBorder()),
                    )),
                  )),
                ]),
                Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text('Actual: ${DateFormat('dd MMM yyyy').format(fechaFinActual)}', style: TextStyle(color: Colors.blue, fontSize: 12)),
                  ])),
                SizedBox(height: 20),

                // Guardar
                ElevatedButton.icon(onPressed: saldoValido ? () => _guardarEdicion(montoCtrl, saldoCtrl, nuevaFechaFin) : null,
                  icon: Icon(Icons.save), label: Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: EdgeInsets.symmetric(vertical: 14))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _guardarEdicion(TextEditingController montoCtrl, TextEditingController saldoCtrl, DateTime nuevaFechaFin) async {
    final nuevoMonto = double.tryParse(montoCtrl.text) ?? 0;
    final nuevoSaldo = double.tryParse(saldoCtrl.text) ?? 0;
    final p = widget.prestamo;

    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text('¿Confirmar cambios?', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _confirmRow('Monto prestado', '\$${nuevoMonto.toStringAsFixed(0)}'),
        _confirmRow('Saldo pendiente', '\$${nuevoSaldo.toStringAsFixed(0)}'),
        _confirmRow('Nueva fecha fin', DateFormat('dd MMM yyyy').format(nuevaFechaFin)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          child: Text('Confirmar', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (confirmar != true || !mounted) return;

    Navigator.pop(context);
    final response = await ApiClient.put('${Constants.apiUrl}/api/loans/${p['id']}', {
      'monto_prestado': nuevoMonto,
      'saldo_pendiente': nuevoSaldo,
      'fecha_fin': DateFormat('yyyy-MM-dd').format(nuevaFechaFin),
    });

    if (response?.statusCode == 200 && mounted) {
      setState(() {
        p['monto_prestado'] = nuevoMonto.toString();
        p['saldo_pendiente'] = nuevoSaldo.toString();
        p['fecha_fin'] = DateFormat('yyyy-MM-dd').format(nuevaFechaFin);
      });
      _showSnack('✅ Préstamo actualizado', Colors.green);
    } else {
      _showSnack('❌ ${jsonDecode(response?.body ?? '{}')['error'] ?? 'Error desconocido'}', Colors.red);
    }
  }

  // ── ✅ RENOVAR DEUDA (CLIENTE ELIGE MONTOS) ──────────────────
  void _renovarDeuda() {
    final saldoActual = double.parse(widget.prestamo['saldo_pendiente'].toString());
    late TextEditingController montoRenovarCtrl, montoPagarCtrl;

    montoRenovarCtrl = TextEditingController(text: saldoActual.toStringAsFixed(0));
    montoPagarCtrl = TextEditingController(text: (saldoActual * 1.20).toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Icon(Icons.refresh, color: Colors.orange), SizedBox(width: 8),
              Text('Renovar Deuda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]),
            Text('El cliente elige los montos', style: TextStyle(color: Colors.grey)),
            Divider(height: 24),

            Text('Monto a Renovar', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            TextField(controller: montoRenovarCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(),
                helperText: 'Hasta el saldo actual: \$${saldoActual.toStringAsFixed(0)}')),

            SizedBox(height: 16),
            Text('Nuevo Monto a Pagar', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            TextField(controller: montoPagarCtrl, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(prefixText: '\$ ', border: OutlineInputBorder(),
                helperText: 'Mínimo 110% del monto renovado')),

            SizedBox(height: 20),
            ElevatedButton.icon(onPressed: () => _confirmarRenovacion(montoRenovarCtrl, montoPagarCtrl),
              icon: Icon(Icons.save), label: Text('Renovar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(vertical: 14))),
          ]),
        ),
      ),
    );
  }

  Future<void> _confirmarRenovacion(TextEditingController montoRenovarCtrl, TextEditingController montoPagarCtrl) async {
    final montoRenovar = double.tryParse(montoRenovarCtrl.text) ?? 0;
    final montoPagar = double.tryParse(montoPagarCtrl.text) ?? 0;
    final saldoActual = double.parse(widget.prestamo['saldo_pendiente'].toString());

    if (montoRenovar <= 0 || montoRenovar > saldoActual || montoPagar < montoRenovar * 1.10) {
      _showSnack('❌ Montos inválidos', Colors.red);
      return;
    }

    Navigator.pop(context);
    final response = await ApiClient.post('${Constants.apiUrl}/api/payments/renew', {
      'prestamo_id': widget.prestamo['id'],
      'monto_renovar': montoRenovar,
      'monto_pagar': montoPagar,
      'dias_plazo': 30,
    });

    if (response?.statusCode == 201 && mounted) {
      _showSnack('✅ Deuda renovada exitosamente', Colors.green);
      Navigator.pop(context);
    } else {
      _showSnack('❌ Error al renovar', Colors.red);
    }
  }

  // ── HELPERS OPTIMIZADOS ─────────────────────────────────────
  Widget _confirmRow(String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.grey)),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  void _showSnack(String mensaje, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mensaje), backgroundColor: color, duration: Duration(seconds: 3)));
    }
  }

  // ── MÉTODOS EXISTENTES (OPTIMIZADOS) ───────────────────────
  void _registrarPago() async {
    final monto = double.tryParse(_montoController.text) ?? 0;
    final saldoActual = double.parse(widget.prestamo['saldo_pendiente'].toString());

    if (monto <= 0) return _showSnack('Monto inválido', Colors.red);
    if (monto > saldoActual) return _showSnack('❌ \$${monto.toStringAsFixed(0)} > \$${saldoActual.toStringAsFixed(0)}', Colors.red);

    if (await _confirmDialog('¿Confirmar pago?', 'Abono de \$${monto.toStringAsFixed(0)}') != true) return;

    final response = await ApiClient.post('${Constants.apiUrl}/api/payments/pay', {
      'prestamo_id': widget.prestamo['id'], 'monto_pagado': monto,
    });
    if (response?.statusCode == 201 && mounted) {
      final data = jsonDecode(response!.body);
      widget.prestamo['saldo_pendiente'] = (data['saldo_restante'] as num).toString();
      _showSnack(data['estado'] == 'pagado' ? '✅ ¡Préstamo pagado!' : '✅ Pago registrado', Colors.green);
      _montoController.clear();
      _cargarHistorial();
      if (data['estado'] == 'pagado') Navigator.pop(context);
    }
  }

  Future<bool?> _confirmDialog(String titulo, String contenido) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold)),
      content: Text(contenido),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: Text('Confirmar', style: TextStyle(color: Colors.white))),
      ],
    ),
  );

  void _editarRutasCobrador() async {
    final cobradorId = widget.prestamo['cobrador_id']?.toString();
    if (cobradorId == null) return _showSnack('Sin cobrador asignado', Colors.red);

    final todasLasRutas = await CobradorService().getRutas();
    final rutasActuales = await CobradorService().getRutasDeCobrador(cobradorId);
    List<int> seleccionadas = rutasActuales.map((r) => int.parse(r['id'].toString())).toList();

    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Editar Rutas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('Cobrador: ${widget.prestamo['usuarios']?['nombre'] ?? 'N/A'}', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 16),
          todasLasRutas.isEmpty ? Text('Sin rutas', style: TextStyle(color: Colors.grey))
              : Wrap(spacing: 8, runSpacing: 4, children: todasLasRutas.map((r) => FilterChip(
                label: Text(r['nombre']), selected: seleccionadas.contains(int.parse(r['id'].toString())),
                selectedColor: Color(0xFFA5D6A7),
                onSelected: (v) => setState(() => v ? seleccionadas.add(int.parse(r['id'].toString())) : seleccionadas.remove(int.parse(r['id'].toString()))),
              )).toList()),
          SizedBox(height: 20),
          ElevatedButton.icon(onPressed: seleccionadas.isEmpty ? null : () async {
            final response = await ApiClient.put('${Constants.apiUrl}/api/rutas/cobrador/$cobradorId', {'rutas_ids': seleccionadas});
            Navigator.pop(ctx);
            _showSnack(response?.statusCode == 200 ? '✅ Rutas actualizadas' : '❌ Error', response?.statusCode == 200 ? Colors.green : Colors.red);
          }, icon: Icon(Icons.save), label: Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF81D4FA), padding: EdgeInsets.symmetric(vertical: 14))),
        ]),
      )),
    );
  }

  void _abrirObservacion() {
    final ctrl = TextEditingController();
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(padding: EdgeInsets.only(left: 16, right: 16, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Reportar Observación', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          TextField(controller: ctrl, maxLines: 4, decoration: InputDecoration(hintText: 'Describe el error...', border: OutlineInputBorder())),
          SizedBox(height: 16),
          ElevatedButton.icon(onPressed: ctrl.text.trim().isEmpty ? null : () async {
            final success = await ObservacionService().createObservacion('prestamo', widget.prestamo['id'] as int, ctrl.text.trim());
            Navigator.pop(ctx);
            _showSnack(success ? '✅ Enviado' : '❌ Error', success ? Colors.green : Colors.red);
          }, icon: Icon(Icons.send), label: Text('Enviar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.symmetric(vertical: 14))),
        ]),
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
    final cliente = p['clientes'];
    final ruta = cliente['rutas'];
    final cobradorNombre = p['usuarios']?['nombre'] ?? 'Sin cobrador';
    final fechaInicio = DateFormat('dd MMM yyyy').format(DateTime.parse(p['fecha_inicio']));
    final fechaFin = DateFormat('dd MMM yyyy').format(DateTime.parse(p['fecha_fin']));
    final saldoPendiente = double.parse(p['saldo_pendiente'].toString());

    return Scaffold(
      backgroundColor: Color(0xFFFBE9E7),
      body: SafeArea(child: SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
            label: Text('Regresar', style: TextStyle(color: Colors.black87, fontSize: 16)),
          )),
          SizedBox(height: 8),

          // Info préstamo
          Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_esAdmin) Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton.icon(onPressed: _editarPrestamo, icon: Icon(Icons.edit, color: Colors.deepPurple, size: 18),
                  label: Text('Editar préstamo', style: TextStyle(color: Colors.deepPurple, fontSize: 12))),
                TextButton.icon(onPressed: _editarRutasCobrador, icon: Icon(Icons.edit_road, color: Colors.blue, size: 18),
                  label: Text('Rutas cobrador', style: TextStyle(color: Colors.blue, fontSize: 12))),
              ]),
              Text('Nombre del Cliente', style: TextStyle(color: Colors.grey)),
              Text(cliente['nombre'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (cliente['telefono'] != null) ...[SizedBox(height: 4), Text('📞 ${cliente['telefono']}', style: TextStyle(color: Colors.grey, fontSize: 13))],
              if (ruta != null) ...[SizedBox(height: 4), Row(children: [
                Icon(Icons.map, size: 14, color: Colors.blue), SizedBox(width: 6),
                Text(ruta['nombre'], style: TextStyle(color: Colors.blue, fontSize: 13)),
              ])],
              SizedBox(height: 4),
              Row(children: [Icon(Icons.person_outline, size: 14, color: Colors.grey), SizedBox(width: 6),
                Text('Cobrador: $cobradorNombre', style: TextStyle(color: Colors.grey, fontSize: 13))]),
              SizedBox(height: 12),
              Text('Monto Prestado', style: TextStyle(color: Colors.grey)),
              Text('\$${double.parse(p['monto_prestado'].toString()).toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Fecha Inicio', style: TextStyle(color: Colors.grey)),
                  Text(fechaInicio, style: TextStyle(fontWeight: FontWeight.bold)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Fecha Fin', style: TextStyle(color: Colors.grey)),
                  Text(fechaFin, style: TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ]),
              SizedBox(height: 12),
              Text('Saldo Pendiente', style: TextStyle(color: Colors.grey)),
              Text('\$${saldoPendiente.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
            ]))),
          SizedBox(height: 16),

          // Registrar abono
          Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Registrar Abono', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 12),
              TextField(controller: _montoController, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(prefixText: '\$ ', hintText: 'Monto del abono',
                  helperText: 'Máx: \$${saldoPendiente.toStringAsFixed(0)}', helperStyle: TextStyle(color: Colors.grey))),
              SizedBox(height: 12),
              ElevatedButton(onPressed: _registrarPago, style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF81C784), padding: EdgeInsets.symmetric(vertical: 14)),
                child: Text('Registrar Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              SizedBox(height: 8),
              OutlinedButton(onPressed: _renovarDeuda, style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange), padding: EdgeInsets.symmetric(vertical: 14)),
                child: Text('Renovar Deuda', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
              SizedBox(height: 8),
              TextButton.icon(onPressed: _abrirObservacion, icon: Icon(Icons.report_problem_outlined, color: Colors.orange),
                label: Text('Reportar error', style: TextStyle(color: Colors.orange))),
            ]))),
          SizedBox(height: 16),

          // Historial
          Text('Historial de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          _isLoading ? Center(child: CircularProgressIndicator())
              : _historial.isEmpty ? Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Text('Sin pagos aún', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center))
              : Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListView.separated(shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
                  itemCount: _historial.length, separatorBuilder: (_,__) => Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final pago = _historial[i];
                    return ListTile(leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Abono registrado'),
                      subtitle: Text(DateFormat('dd MMM yyyy – hh:mm a').format(DateTime.parse(pago['fecha_pago']).toLocal()),
                        style: TextStyle(fontSize: 12)),
                      trailing: Text('\$${double.parse(pago['monto_pagado'].toString()).toStringAsFixed(2)}',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)));
                  })),
        ],
      ))),
    );
  }
}