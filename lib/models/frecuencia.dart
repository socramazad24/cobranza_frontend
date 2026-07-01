// lib/models/frecuencia.dart

class FrecuenciaPago {
  final String id;
  final String label;
  final String icono;
  final int diasPorPeriodo;

  const FrecuenciaPago({
    required this.id,
    required this.label,
    required this.icono,
    required this.diasPorPeriodo,
  });

  double calcularCuota(double montoTotal, int diasPlazo) {
    final numPagos = _numeroPagos(diasPlazo);
    if (numPagos <= 0) return montoTotal;
    return (montoTotal / numPagos);
  }

  int _numeroPagos(int diasPlazo) {
    if (diasPorPeriodo <= 0) return 1;
    return (diasPlazo / diasPorPeriodo).ceil();
  }

  List<DateTime> generarFechas(DateTime fechaInicio, int diasPlazo) {
    final numPagos = _numeroPagos(diasPlazo);
    return List.generate(numPagos, (i) {
      return fechaInicio.add(Duration(days: diasPorPeriodo * (i + 1)));
    });
  }

  static const List<FrecuenciaPago> todas = [
    FrecuenciaPago(id: 'diario', label: 'Diario', icono: '📅', diasPorPeriodo: 1),
    FrecuenciaPago(id: 'semanal', label: 'Semanal', icono: '📆', diasPorPeriodo: 7),
    FrecuenciaPago(id: 'quincenal', label: 'Quincenal', icono: '🗓️', diasPorPeriodo: 15),
    FrecuenciaPago(id: 'mensual', label: 'Mensual', icono: '🗓️', diasPorPeriodo: 30),
  ];

  static FrecuenciaPago fromId(String id) {
    return todas.firstWhere(
      (f) => f.id == id,
      orElse: () => todas.first,
    );
  }
}
