// lib/widgets/calendario_pagos_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/calendario_service.dart';

/// Widget que muestra el calendario de pagos programados de un préstamo.
class CalendarioPagosWidget extends StatelessWidget {
  final int totalPagos;
  final int pagosRealizados;
  final double cuotaPorPeriodo;
  final double montoTotal;
  final String frecuencia;
  final List<Map<String, dynamic>> pagosProgramados;
  final VoidCallback? onPagoRealizado;

  const CalendarioPagosWidget({
    super.key,
    required this.totalPagos,
    required this.pagosRealizados,
    required this.cuotaPorPeriodo,
    required this.montoTotal,
    required this.frecuencia,
    required this.pagosProgramados,
    this.onPagoRealizado,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');
    final progress = totalPagos > 0 ? pagosRealizados / totalPagos : 0.0;
    final proximoPago = pagosProgramados.firstWhere(
      (p) => p['pagado'] == false,
      orElse: () => <String, dynamic>{},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── PROGRESO ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: progress >= 1.0
                  ? [Colors.green.shade300, Colors.green.shade500]
                  : [Colors.blue.shade300, Colors.blue.shade500],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Progreso de pagos',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$pagosRealizados de $totalPagos pagos',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Cuota por $frecuencia: \$${fmt.format(cuotaPorPeriodo)}',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% completado',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── PRÓXIMO PAGO ──
        if (proximoPago.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      '#${proximoPago['numero_pago']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Próximo pago', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        _formatFecha(proximoPago['fecha_programada'] as String?),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${fmt.format((proximoPago['monto_esperado'] as num?)?.toDouble() ?? 0)}',
                        style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (onPagoRealizado != null)
                  IconButton.filled(
                    onPressed: onPagoRealizado,
                    icon: const Icon(Icons.payments, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.green),
                    tooltip: 'Registrar pago',
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // ── TIMELINE DE PAGOS ──
        const Text(
          'Calendario de pagos',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...pagosProgramados.asMap().entries.map((entry) {
          final index = entry.key;
          final pago = entry.value;
          return _PagoTimelineItem(
            pago: pago,
            isLast: index == pagosProgramados.length - 1,
            onPagoRealizado: onPagoRealizado,
          );
        }),
      ],
    );
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return '';
    try {
      final d = DateTime.parse(fecha);
      return DateFormat("d 'de' MMMM, yyyy", 'es_CO').format(d);
    } catch (_) {
      return fecha;
    }
  }
}

class _PagoTimelineItem extends StatelessWidget {
  final Map<String, dynamic> pago;
  final bool isLast;
  final VoidCallback? onPagoRealizado;

  const _PagoTimelineItem({
    required this.pago,
    required this.isLast,
    this.onPagoRealizado,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');
    final fecha = pago['fecha_programada'] as String?;
    final numeroPago = pago['numero_pago'] as int? ?? 0;
    final monto = (pago['monto_esperado'] as num?)?.toDouble() ?? 0;
    final pagado = pago['pagado'] == true;
    final hoy = DateTime.now();
    final fechaPago = fecha != null ? DateTime.tryParse(fecha) : null;
    final esVencido = fechaPago != null && fechaPago.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
    final esHoy = fechaPago != null && fechaPago.year == hoy.year && fechaPago.month == hoy.month && fechaPago.day == hoy.day;

    final Color colorEstado = pagado
        ? Colors.green
        : esVencido
            ? Colors.red
            : esHoy
                ? Colors.amber
                : Colors.grey;

    final IconData iconoEstado = pagado
        ? Icons.check_circle
        : esVencido
            ? Icons.error
            : esHoy
                ? Icons.today
                : Icons.radio_button_unchecked;

    final String textoEstado = pagado
        ? 'Pagado'
        : esVencido
            ? 'Vencido'
            : esHoy
                ? 'HOY'
                : 'Pendiente';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── LÍNEA DE TIEMPO ──
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorEstado.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: colorEstado, width: 2),
                ),
                child: Icon(iconoEstado, color: colorEstado, size: 18),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 50,
                  color: Colors.grey.shade300,
                ),
            ],
          ),
          const SizedBox(width: 12),
          // ── CONTENIDO ──
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: pagado
                    ? Colors.green.shade50
                    : esHoy
                        ? Colors.amber.shade50
                        : esVencido
                            ? Colors.red.shade50
                            : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorEstado.withOpacity(0.3),
                  width: esHoy ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Pago #$numeroPago',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        textoEstado,
                        style: TextStyle(
                          color: colorEstado,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _formatFechaCorta(fecha),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      Text(
                        '\$${fmt.format(monto)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorEstado,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (esHoy && !pagado && onPagoRealizado != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onPagoRealizado,
                        icon: const Icon(Icons.payments, size: 18),
                        label: const Text('Registrar pago ahora'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFechaCorta(String? fecha) {
    if (fecha == null) return '';
    try {
      final d = DateTime.parse(fecha);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return fecha;
    }
  }
}

/// Widget para mostrar las "Cuotas del día" del cobrador
class CuotasDelDiaWidget extends StatelessWidget {
  final CuotasDelDia cuotasDelDia;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final Function(CuotaProgramada)? onCuotaTap;

  const CuotasDelDiaWidget({
    super.key,
    required this.cuotasDelDia,
    required this.isLoading,
    this.onRefresh,
    this.onCuotaTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_CO');
    final progress = cuotasDelDia.totalEsperado > 0
        ? (cuotasDelDia.totalPagadoHoy / cuotasDelDia.totalEsperado).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.today, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'CUOTAS DE HOY',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
              ),
              const Spacer(),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: onRefresh,
                  tooltip: 'Actualizar',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cuotasDelDia.totalCuotasPendientes}',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const Text('clientes pendientes', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${fmt.format(cuotasDelDia.totalEsperado)}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'cobrado: \$${fmt.format(cuotasDelDia.totalPagadoHoy)}',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          if (cuotasDelDia.cuotas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  ...cuotasDelDia.cuotas.take(3).map((c) {
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Text(
                          c.clienteNombre.isNotEmpty ? c.clienteNombre[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        c.clienteNombre,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '#${c.numeroPago} · \$${fmt.format(c.montoEsperado)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                      onTap: onCuotaTap == null ? null : () => onCuotaTap!(c),
                    );
                  }),
                  if (cuotasDelDia.cuotas.length > 3)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '+ ${cuotasDelDia.cuotas.length - 3} más',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
