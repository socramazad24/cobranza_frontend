// lib/widgets/frecuencia_selector.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/frecuencia.dart';

/// Widget reutilizable para seleccionar frecuencia de pago.
class FrecuenciaSelector extends StatelessWidget {
  final String frecuenciaSeleccionada;
  final ValueChanged<String> onChanged;
  final double montoTotal;
  final int diasPlazo;

  const FrecuenciaSelector({
    super.key,
    required this.frecuenciaSeleccionada,
    required this.onChanged,
    required this.montoTotal,
    required this.diasPlazo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Frecuencia de pago',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: FrecuenciaPago.todas.map((f) {
            final seleccionada = f.id == frecuenciaSeleccionada;
            final cuota = montoTotal > 0
                ? f.calcularCuota(montoTotal, diasPlazo)
                : 0.0;
            final numPagos = montoTotal > 0
                ? (diasPlazo / f.diasPorPeriodo).ceil()
                : 0;

            return _OpcionFrecuencia(
              frecuencia: f,
              seleccionada: seleccionada,
              cuota: cuota,
              numPagos: numPagos,
              onTap: () => onChanged(f.id),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _OpcionFrecuencia extends StatelessWidget {
  final FrecuenciaPago frecuencia;
  final bool seleccionada;
  final double cuota;
  final int numPagos;
  final VoidCallback onTap;

  const _OpcionFrecuencia({
    required this.frecuencia,
    required this.seleccionada,
    required this.cuota,
    required this.numPagos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionada ? Colors.amber.shade50 : Colors.white,
          border: Border.all(
            color: seleccionada ? Colors.amber : Colors.grey.shade300,
            width: seleccionada ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  frecuencia.icono,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 6),
                Text(
                  frecuencia.label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: seleccionada
                        ? Colors.amber.shade800
                        : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (seleccionada)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.amber,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '\$${fmt.format(cuota)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              '$numPagos pagos en ${frecuencia.diasPorPeriodo} días',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
