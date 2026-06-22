import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/http_client.dart';

class ClavosScreen extends StatefulWidget {
  const ClavosScreen({super.key});

  @override
  State<ClavosScreen> createState() => _ClavosScreenState();
}

class _ClavosScreenState extends State<ClavosScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _clavos = [];
  int _totalActivos = 0;
  bool _isLoading = false;
  bool _dataCargada = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataCargada) {
      _dataCargada = true;
      _cargarDatos();
    }
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final clavosRes =
          await ApiClient.get('${Constants.apiUrl}/api/loans/clavos');
      final activosRes =
          await ApiClient.get('${Constants.apiUrl}/api/reports/resumen');

      if (!mounted) return;

      if (clavosRes != null && clavosRes.statusCode == 200) {
        final clavosData = jsonDecode(clavosRes.body);

        int totalActivos = 0;
        if (activosRes != null && activosRes.statusCode == 200) {
          final resumen = jsonDecode(activosRes.body);
          totalActivos =
              (resumen['cantidad_prestamos_activos'] as num?)?.toInt() ?? 0;
        }

        final clavosList = clavosData is List
            ? clavosData
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];

        setState(() {
          _clavos = clavosList;
          _totalActivos = totalActivos;
          _isLoading = false;
        });
      } else {
        final errorBody = clavosRes?.body ?? 'Sin respuesta';
        throw Exception('Error ${clavosRes?.statusCode}: $errorBody');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _dataCargada = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando clavos: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Reintentar',
            textColor: Colors.white,
            onPressed: () {
              setState(() => _dataCargada = false);
              _cargarDatos();
            },
          ),
        ),
      );
    }
  }

  Future<void> _recargar() async {
    setState(() {
      _dataCargada = false;
      _clavos = [];
    });
    await _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFFFEBEE),
      child: RefreshIndicator(
        onRefresh: _recargar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF81D4FA),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Préstamos Activos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_totalActivos',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCDD2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Clavos',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_clavos.length}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_clavos.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      '⚠️ ${_clavos.length} clientes en mora',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Clientes Morosos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _clavos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 60),
                          SizedBox(height: 12),
                          Text(
                            '¡Sin clientes morosos! 🎉',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _clavos.length,
                    itemBuilder: (context, index) {
                      final clavo = _clavos[index];
                      final nombre =
                          (clavo['nombre_cliente'] ?? 'Sin nombre').toString();
                      final dias =
                          (clavo['dias_sin_pago'] as num?)?.toInt() ?? 0;
                      final saldo =
                          (clavo['saldo_pendiente'] as num?)?.toDouble() ?? 0;
                      final cobrador = (clavo['cobrador'] ?? '').toString();

                      final Color colorDias = dias >= 10
                          ? Colors.red
                          : dias >= 5
                              ? Colors.orange
                              : Colors.yellow[800]!;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.red[100],
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (cobrador.isNotEmpty)
                                      Text(
                                        'Cobrador: $cobrador',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (saldo > 0)
                                      Text(
                                        'Saldo: \$${saldo.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorDias.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: colorDias),
                                    ),
                                    child: Text(
                                      '$dias días',
                                      style: TextStyle(
                                        color: colorDias,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'CLAVO',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}