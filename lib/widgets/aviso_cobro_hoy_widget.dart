// lib/widgets/aviso_cobro_hoy_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/calendario_service.dart';

/// Banner que avisa si ya se cobró hoy a este préstamo
class AvisoCobroHoyWidget extends StatelessWidget {
  final PagosHoyPrestamo pagosHoy;
  final double cuotaEsperada;
  final VoidCallback? onVerDetalle;

  const AvisoCobroHoyWidget({
    super.key,
    required this.pagosHoy,
    required this.cuotaEsperada,
    this.onVerDetalle,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');
    final total = pagosHoy.totalCobradoHoy;
    final cantidad = pagosHoy.cantidadPagos;

    if (cantidad == 0) {
      // 🆕 NO ha cobrado hoy, mostrar sugerencia
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.today, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cuota de hoy',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${fmt.format(cuotaEsperada)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'No has cobrado hoy a este cliente',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Ya cobró al menos una vez hoy
    final superaCuota = total > cuotaEsperada;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: superaCuota ? Colors.red.shade50 : Colors.orange.shade50,
        border: Border.all(
          color: superaCuota ? Colors.red.shade300 : Colors.orange.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: superaCuota ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  superaCuota ? Icons.warning_amber : Icons.info_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      superaCuota
                          ? '⚠️ Ya cobraste de MÁS hoy'
                          : '⚠️ Ya cobraste hoy a este cliente',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: superaCuota ? Colors.red.shade900 : Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total cobrado HOY: \$${fmt.format(total)} (${cantidad == 1 ? "1 pago" : "$cantidad pagos"})',
                      style: TextStyle(
                        fontSize: 12,
                        color: superaCuota ? Colors.red.shade800 : Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Lista de pagos de hoy
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: pagosHoy.pagos.map((p) {
                final hora = DateFormat('hh:mm a').format(p.fecha.toLocal());
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        hora,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const Spacer(),
                      Text(
                        '\$${fmt.format(p.monto)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (superaCuota) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'El total cobrado (\$${fmt.format(total)}) supera la cuota del día (\$${fmt.format(cuotaEsperada)})',
                      style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Sugerencia
          Row(
            children: [
              Icon(
                Icons.lightbulb,
                size: 14,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  superaCuota
                      ? 'Verifica que sea correcto antes de registrar otro pago'
                      : '¿Vas a registrar OTRO pago hoy?',
                  style: const TextStyle(fontSize: 11, color: Colors.black87, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
