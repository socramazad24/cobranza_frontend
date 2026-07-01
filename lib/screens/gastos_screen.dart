// lib/screens/gastos_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend_flutter/providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/expense_service.dart';
import '../services/cobrador_service.dart';

class GastosScreen extends StatefulWidget {
  const GastosScreen({super.key});

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final CobradorService _cobradorService = CobradorService();

  List<dynamic> _todosLosGastos = [];
  List<dynamic> _gastosFiltrados = [];
  List<dynamic> _cobradores = [];
  Map<String, double> _totalesPorTipo = {};

  String? _cobradorFiltro;
  String _tipoFiltro = 'todos';
  String _orden = 'reciente';
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  bool _isLoading = true;
  bool _esAdmin = false;

  static const List<String> _tiposGasto = [
    'Alimentación',
    'Combustible',
    'Transporte',
    'Mantenimiento',
    'Papelería',
    'Servicios',
    'Peajes',
    'Multas',
    'Salarios',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final rol = await AuthProvider.getRol();
    if (mounted) setState(() => _esAdmin = rol == 'admin');

    if (_esAdmin) {
      final cobradores = await _cobradorService.getCobradores();
      if (mounted) setState(() => _cobradores = cobradores);
    }

    final gastos = await _expenseService.getExpenses();
    if (!mounted) return;

    setState(() {
      _todosLosGastos = gastos ?? [];
      _calcularTotalesPorTipo();
      _isLoading = false;
    });
    _aplicarFiltros();
  }

  void _calcularTotalesPorTipo() {
    final mapa = <String, double>{};
    for (final g in _todosLosGastos) {
      if (g is Map) {
        final tipo = g['tipo_gasto']?.toString() ?? 'Otro';
        final valor = _toDouble(g['valor']);
        mapa[tipo] = (mapa[tipo] ?? 0) + valor;
      }
    }
    setState(() => _totalesPorTipo = mapa);
  }

  void _aplicarFiltros() {
    if (!mounted) return;

    final resultado = <dynamic>[];

    for (final item in _todosLosGastos) {
      if (item is! Map) continue;

      // 1. Filtro por cobrador
      if (_cobradorFiltro != null) {
        final cobradorId = item['cobrador_id']?.toString();
        if (cobradorId != _cobradorFiltro) continue;
      }

      // 2. Filtro por tipo
      if (_tipoFiltro != 'todos') {
        final tipo = item['tipo_gasto']?.toString();
        if (tipo != _tipoFiltro) continue;
      }

      // 3. Filtro por fecha
      if (_fechaDesde != null || _fechaHasta != null) {
        try {
          final fecha = DateTime.parse(item['fecha'].toString());
          if (_fechaDesde != null && fecha.isBefore(_fechaDesde!)) continue;
          if (_fechaHasta != null && fecha.isAfter(_fechaHasta!.add(const Duration(days: 1)))) continue;
        } catch (_) {
          continue;
        }
      }

      resultado.add(item);
    }

    // 4. Orden
    switch (_orden) {
      case 'mayor':
        resultado.sort((a, b) => _toDouble((b as Map)['valor']).compareTo(_toDouble((a as Map)['valor'])));
        break;
      case 'menor':
        resultado.sort((a, b) => _toDouble((a as Map)['valor']).compareTo(_toDouble((b as Map)['valor'])));
        break;
      case 'tipo':
        resultado.sort((a, b) => ((a as Map)['tipo_gasto']?.toString() ?? '').compareTo((b as Map)['tipo_gasto']?.toString() ?? ''));
        break;
      case 'reciente':
      default:
        resultado.sort((a, b) {
          DateTime? fa;
          DateTime? fb;
          try {
            fa = DateTime.parse((a as Map)['fecha'].toString());
          } catch (_) {}
          try {
            fb = DateTime.parse((b as Map)['fecha'].toString());
          } catch (_) {}
          if (fa == null && fb == null) return 0;
          if (fa == null) return 1;
          if (fb == null) return -1;
          return fb.compareTo(fa);
        });
    }

    setState(() {
      _gastosFiltrados = resultado;
    });
  }

  Future<void> _abrirFormularioGasto({Map? gastoEditar}) async {
    final montoController = TextEditingController(
      text: gastoEditar != null ? _toDouble(gastoEditar['valor']).toStringAsFixed(0) : '',
    );
    final descripcionController = TextEditingController(
      text: gastoEditar?['descripcion']?.toString() ?? '',
    );
    String? tipoSeleccionado = gastoEditar?['tipo_gasto']?.toString() ?? _tiposGasto.first;
    String? cobradorSeleccionadoId = _esAdmin ? null : (await AuthProvider.getUserId());
    File? imagenSeleccionada;
    String? imagenExistente = gastoEditar?['comprobante_url']?.toString();
    bool subiendo = false;
    bool esEdicion = gastoEditar != null;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
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
                Row(
                  children: [
                    Icon(esEdicion ? Icons.edit : Icons.add_circle, color: Colors.purple),
                    const SizedBox(width: 8),
                    Text(
                      esEdicion ? 'Editar Gasto' : 'Registrar Gasto',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Tipo de gasto *',
                    prefixIcon: Icon(Icons.category),
                  ),
                  value: tipoSeleccionado,
                  items: _tiposGasto.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setModalState(() => tipoSeleccionado = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto *',
                    prefixText: '\$ ',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    prefixIcon: Icon(Icons.notes),
                    hintText: 'Ej: gasolina para moto Honda',
                  ),
                ),
                if (_esAdmin) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Cobrador',
                      prefixIcon: Icon(Icons.motorcycle),
                    ),
                    value: cobradorSeleccionadoId,
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Asignarme a mí (admin)')),
                      ..._cobradores.map((c) => DropdownMenuItem<String>(
                            value: c['id'].toString(),
                            child: Text(c['nombre']?.toString() ?? ''),
                          )),
                    ],
                    onChanged: (v) => setModalState(() => cobradorSeleccionadoId = v),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Comprobante', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (picked != null) {
                      setModalState(() => imagenSeleccionada = File(picked.path));
                    }
                  },
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: imagenSeleccionada != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(imagenSeleccionada!, fit: BoxFit.cover),
                          )
                        : imagenExistente != null
                            ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(imagenExistente, fit: BoxFit.cover, width: double.infinity),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Actual', style: TextStyle(color: Colors.white, fontSize: 10)),
                                    ),
                                  ),
                                ],
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Toca para adjuntar foto', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 20),
                subiendo
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: () async {
                          final monto = _toDouble(montoController.text);
                          if (tipoSeleccionado == null || monto <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tipo y monto son requeridos'), backgroundColor: Colors.red),
                            );
                            return;
                          }
                          setModalState(() => subiendo = true);

                          String? url = imagenExistente;
                          if (imagenSeleccionada != null) {
                            url = await _expenseService.uploadComprobante(imagenSeleccionada!);
                            if (url == null) {
                              setModalState(() => subiendo = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('❌ Error subiendo comprobante'), backgroundColor: Colors.red),
                                );
                              }
                              return;
                            }
                          }

                          bool success;
                          if (esEdicion) {
                            success = false; // TODO
                          } else {
                            success = await _expenseService.createExpense(
                              tipoSeleccionado!,
                              monto,
                              cobradorSeleccionadoId,
                              url,
                            );
                          }

                          setModalState(() => subiendo = false);
                          if (context.mounted) {
                            Navigator.pop(context, success);
                          }
                        },
                        icon: Icon(esEdicion ? Icons.save : Icons.add),
                        label: Text(esEdicion ? 'Guardar Cambios' : 'Registrar Gasto',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

    if (result == true) {
      await _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(esEdicion ? '✅ Gasto actualizado' : '✅ Gasto registrado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _seleccionarRangoFechas() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _fechaDesde != null && _fechaHasta != null
          ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _fechaDesde = picked.start;
        _fechaHasta = picked.end;
      });
      _aplicarFiltros();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════
  double _toDouble(dynamic value, {double defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  String _safeStr(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  Color _colorPorTipo(String tipo) {
    switch (tipo) {
      case 'Alimentación':
        return Colors.orange;
      case 'Combustible':
        return Colors.red;
      case 'Transporte':
        return Colors.blue;
      case 'Mantenimiento':
        return Colors.purple;
      case 'Papelería':
        return Colors.teal;
      case 'Servicios':
        return Colors.cyan;
      case 'Peajes':
        return Colors.indigo;
      case 'Multas':
        return Colors.red.shade900;
      case 'Salarios':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _iconoPorTipo(String tipo) {
    switch (tipo) {
      case 'Alimentación':
        return Icons.restaurant;
      case 'Combustible':
        return Icons.local_gas_station;
      case 'Transporte':
        return Icons.directions_bus;
      case 'Mantenimiento':
        return Icons.build;
      case 'Papelería':
        return Icons.description;
      case 'Servicios':
        return Icons.electrical_services;
      case 'Peajes':
        return Icons.toll;
      case 'Multas':
        return Icons.gavel;
      case 'Salarios':
        return Icons.people;
      default:
        return Icons.receipt_long;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading && _todosLosGastos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final fmt = NumberFormat('#,##0', 'es_CO');

    // Calcular totales filtrados
    double totalFiltrado = 0;
    for (final g in _gastosFiltrados) {
      if (g is Map) totalFiltrado += _toDouble(g['valor']);
    }
    final cantidadFiltrada = _gastosFiltrados.length;

    // Calcular top categorías en el filtro actual
    final totalesFiltrados = <String, double>{};
    for (final g in _gastosFiltrados) {
      if (g is Map) {
        final tipo = _safeStr(g['tipo_gasto'], defaultValue: 'Otro');
        totalesFiltrados[tipo] = (totalesFiltrados[tipo] ?? 0) + _toDouble(g['valor']);
      }
    }
    final topCategorias = totalesFiltrados.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final filtrosActivos = _fechaDesde != null || _cobradorFiltro != null || _tipoFiltro != 'todos';

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildResumenCard(fmt, totalFiltrado, cantidadFiltrada, topCategorias),
            ),
            SliverToBoxAdapter(
              child: _buildBarraFiltros(fmt),
            ),
            if (filtrosActivos)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_alt, size: 14, color: Colors.purple),
                      const SizedBox(width: 4),
                      Text(
                        '${_gastosFiltrados.length} de ${_todosLosGastos.length} gastos',
                        style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _cobradorFiltro = null;
                            _tipoFiltro = 'todos';
                            _fechaDesde = null;
                            _fechaHasta = null;
                          });
                          _aplicarFiltros();
                        },
                        child: const Text(
                          'Limpiar',
                          style: TextStyle(fontSize: 11, color: Colors.purple, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_gastosFiltrados.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        _todosLosGastos.isEmpty
                            ? 'No hay gastos registrados'
                            : 'Sin resultados con los filtros',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      if (_todosLosGastos.isEmpty) ...[
                        const SizedBox(height: 12),
                        if (_esAdmin)
                          ElevatedButton.icon(
                            onPressed: () => _abrirFormularioGasto(),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Registrar primer gasto'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                          ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final g = _gastosFiltrados[index] as Map;
                      return _buildGastoCard(g, fmt);
                    },
                    childCount: _gastosFiltrados.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _esAdmin
          ? FloatingActionButton.extended(
              heroTag: 'gastos-fab',
              onPressed: () => _abrirFormularioGasto(),
              backgroundColor: const Color(0xFFCE93D8),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo Gasto',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  WIDGETS
  // ═══════════════════════════════════════════════════════════
  Widget _buildResumenCard(NumberFormat fmt, double total, int cantidad, List<MapEntry<String, double>> topCategorias) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.savings, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('GASTOS',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$${fmt.format(total)}',
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    Text(cantidad == 1 ? '1 gasto' : '$cantidad gastos',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                  ],
                ),
              ),
              if (topCategorias.isNotEmpty)
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 8),
                  ),
                  child: Center(
                    child: Icon(
                      _iconoPorTipo(topCategorias.first.key),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
            ],
          ),
          if (topCategorias.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
            ...topCategorias.take(3).map((e) {
              final pct = total > 0 ? (e.value / total * 100) : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(_iconoPorTipo(e.key), color: Colors.white70, size: 12),
                    const SizedBox(width: 6),
                    Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white, fontSize: 12))),
                    Text('\$${fmt.format(e.value)} (${pct.toStringAsFixed(0)}%)',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBarraFiltros(NumberFormat fmt) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              if (_esAdmin && _cobradores.isNotEmpty)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _cobradorFiltro,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        style: const TextStyle(fontSize: 13),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('👥 Todos los cobradores')),
                          ..._cobradores.map((c) => DropdownMenuItem<String?>(
                                value: c['id'].toString(),
                                child: Text(c['nombre']?.toString() ?? ''),
                              )),
                        ],
                        onChanged: (v) {
                          setState(() => _cobradorFiltro = v);
                          _aplicarFiltros();
                        },
                      ),
                    ),
                  ),
                ),
              if (_esAdmin) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tipoFiltro,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      style: const TextStyle(fontSize: 13),
                      items: [
                        const DropdownMenuItem<String>(value: 'todos', child: Text('📋 Todos los tipos')),
                        ..._tiposGasto.map((t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _tipoFiltro = v ?? 'todos');
                        _aplicarFiltros();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _seleccionarRangoFechas,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: _fechaDesde != null ? Colors.purple.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: _fechaDesde != null
                          ? Border.all(color: Colors.purple.shade200)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: _fechaDesde != null ? Colors.purple : Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _fechaDesde == null
                                ? '📅 Rango de fechas'
                                : '${DateFormat('dd/MM').format(_fechaDesde!)} - ${DateFormat('dd/MM').format(_fechaHasta!)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: _fechaDesde != null ? Colors.purple : Colors.grey.shade700,
                              fontWeight: _fechaDesde != null ? FontWeight.bold : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_fechaDesde != null)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _fechaDesde = null;
                                _fechaHasta = null;
                              });
                              _aplicarFiltros();
                            },
                            child: const Icon(Icons.close, size: 16, color: Colors.purple),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                initialValue: _orden,
                tooltip: 'Ordenar',
                onSelected: (v) {
                  setState(() => _orden = v);
                  _aplicarFiltros();
                },
                itemBuilder: (ctx) => [
                  _menuItem('reciente', '🕐 Más reciente', _orden),
                  _menuItem('mayor', '💰 Mayor monto', _orden),
                  _menuItem('menor', '🪙 Menor monto', _orden),
                  _menuItem('tipo', '🏷️ Por tipo', _orden),
                ],
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sort, size: 18, color: Colors.black54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, String label, String current) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(current == value ? Icons.check : Icons.circle_outlined, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildGastoCard(Map gasto, NumberFormat fmt) {
    final tipo = _safeStr(gasto['tipo_gasto'], defaultValue: 'Otro');
    final valor = _toDouble(gasto['valor']);
    final cobrador = _safeStr(gasto['usuarios']?['nombre'], defaultValue: 'Sin asignar');
    final fecha = _safeStr(gasto['fecha']);
    final fechaFmt = _formatearFecha(fecha);
    final tieneComprobante = gasto['comprobante_url'] != null;
    final descripcion = _safeStr(gasto['descripcion']);
    final color = _colorPorTipo(tipo);
    final icono = _iconoPorTipo(tipo);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: tieneComprobante ? () => _verComprobante(gasto['comprobante_url'].toString(), tipo) : null,
          onLongPress: _esAdmin ? () => _mostrarOpcionesGasto(gasto) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icono, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tipo,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          Text(
                            '\$${fmt.format(valor)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.motorcycle, size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              cobrador,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.calendar_today, size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(fechaFmt, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                        ],
                      ),
                      if (descripcion.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(descripcion, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                      ],
                      if (tieneComprobante) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.attach_file, size: 11, color: Colors.green.shade600),
                            const SizedBox(width: 3),
                            Text('Comprobante adjunto', style: TextStyle(fontSize: 10, color: Colors.green.shade600)),
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
      ),
    );
  }

  void _verComprobante(String url, String tipo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Comprobante: $tipo'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
              backgroundColor: Colors.purple,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400, maxWidth: 400),
              child: Image.network(url, fit: BoxFit.contain, loadingBuilder: (_, child, p) {
                return p == null ? child : const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator());
              }, errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(40),
                child: Text('❌ No se pudo cargar la imagen'),
              )),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesGasto(Map gasto) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gasto['comprobante_url'] != null)
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('Ver comprobante'),
                onTap: () {
                  Navigator.pop(ctx);
                  _verComprobante(gasto['comprobante_url'].toString(), _safeStr(gasto['tipo_gasto']));
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.grey),
              title: const Text('Duplicar gasto'),
              onTap: () {
                Navigator.pop(ctx);
                _abrirFormularioGasto();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return '';
    try {
      final d = DateTime.parse(fecha);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return fecha.substring(0, fecha.length >= 10 ? 10 : fecha.length);
    }
  }
}
