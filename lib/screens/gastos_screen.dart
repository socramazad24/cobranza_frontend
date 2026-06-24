// lib/screens/gastos_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/expense_service.dart';
import '../services/cobrador_service.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final ExpenseService _expenseService = ExpenseService();
  List<dynamic> _gastos = [];
  List<dynamic> _cobradores = [];
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
    setState(() => _esAdmin = rol == 'admin');

    if (_esAdmin) {
      final cobradores = await CobradorService().getCobradores();
      setState(() => _cobradores = cobradores);
    }

    final gastos = await _expenseService.getExpenses();
    if (mounted) {
      setState(() {
        _gastos = gastos;
        _isLoading = false;
      });
    }
  }

  void _abrirFormularioGasto() {
    final montoController = TextEditingController();
    String? tipoSeleccionado;
    String? cobradorSeleccionadoId;
    File? imagenSeleccionada;
    bool subiendo = false;

    final List<String> tipos = [
      'Alimentación', 'Combustible', 'Mantenimiento', 'Papelería', 'Otro'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Registrar Gasto',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Tipo de gasto *'),
                  value: tipoSeleccionado,
                  items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setModalState(() => tipoSeleccionado = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monto *', prefixText: '\$ '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Cobrador asociado (opcional)'),
                  value: cobradorSeleccionadoId,
                  items: _cobradores.map((c) => DropdownMenuItem<String>(
                    value: c['id'].toString(),
                    child: Text(c['nombre']),
                  )).toList(),
                  onChanged: (v) => setModalState(() => cobradorSeleccionadoId = v),
                ),
                const SizedBox(height: 16),
                const Text('Comprobante (opcional)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                        source: ImageSource.gallery, imageQuality: 70);
                    if (picked != null) {
                      setModalState(() => imagenSeleccionada = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: imagenSeleccionada != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(imagenSeleccionada!, fit: BoxFit.cover))
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Toca para adjuntar foto (opcional)',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                subiendo
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: () async {
                          final monto = double.tryParse(montoController.text) ?? 0;
                          if (tipoSeleccionado == null || monto <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tipo y monto son requeridos'),
                                  backgroundColor: Colors.red),
                            );
                            return;
                          }
                          setModalState(() => subiendo = true);
                          String? url;
                          if (imagenSeleccionada != null) {
                            url = await _expenseService.uploadComprobante(imagenSeleccionada!);
                            if (url == null) {
                              setModalState(() => subiendo = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('❌ Error subiendo comprobante'),
                                      backgroundColor: Colors.red),
                                );
                              }
                              return;
                            }
                          }
                          final success = await _expenseService.createExpense(
                              tipoSeleccionado!, monto, cobradorSeleccionadoId, url);
                          setModalState(() => subiendo = false);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? '✅ Gasto registrado correctamente'
                                    : '❌ Error al registrar gasto'),
                                backgroundColor: success ? Colors.green : Colors.red,
                              ),
                            );
                            if (success) _cargarDatos();
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Gasto',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFCE93D8),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      floatingActionButton: _esAdmin
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: _abrirFormularioGasto,
              backgroundColor: const Color(0xFFCE93D8),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Gasto',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(         // ✅ Pull to refresh
              onRefresh: _cargarDatos,
              child: _gastos.isEmpty
                  ? ListView(         // ✅ ListView para que pull to refresh funcione en pantalla vacía
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.4),
                        Center(
                          child: Text(
                            _esAdmin
                                ? 'No hay gastos registrados.\nPresiona + para agregar.'
                                : 'No hay gastos asignados a tu cuenta.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _gastos.length,
                      itemBuilder: (context, index) {
                        final gasto = _gastos[index];
                        final cobrador = gasto['usuarios']?['nombre'] ?? 'Sin asignar';
                        final fecha = DateFormat('dd MMM yyyy')
                            .format(DateTime.parse(gasto['fecha']).toLocal());
                        final tieneComprobante = gasto['comprobante_url'] != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple[100],
                              child: const Icon(Icons.receipt_long, color: Colors.purple),
                            ),
                            title: Text(gasto['tipo_gasto'],
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$cobrador • $fecha'),
                                tieneComprobante
                                    ? const Row(children: [
                                        Icon(Icons.attach_file, size: 12, color: Colors.green),
                                        SizedBox(width: 4),
                                        Text('Con comprobante',
                                            style: TextStyle(color: Colors.green, fontSize: 11)),
                                      ])
                                    : const Row(children: [
                                        Icon(Icons.info_outline, size: 12, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('Sin comprobante',
                                            style: TextStyle(color: Colors.grey, fontSize: 11)),
                                      ]),
                              ],
                            ),
                            trailing: Text(
                              '\$${double.parse(gasto['valor'].toString()).toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.purple),
                            ),
                            onTap: tieneComprobante
                                ? () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AppBar(
                                              title: const Text('Comprobante'),
                                              leading: IconButton(
                                                icon: const Icon(Icons.close),
                                                onPressed: () => Navigator.pop(context),
                                              ),
                                              backgroundColor: const Color(0xFFCE93D8),
                                            ),
                                            Image.network(
                                              gasto['comprobante_url'],
                                              fit: BoxFit.contain,
                                              loadingBuilder: (_, child, progress) =>
                                                  progress == null
                                                      ? child
                                                      : const Padding(
                                                          padding: EdgeInsets.all(32),
                                                          child: CircularProgressIndicator(),
                                                        ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}