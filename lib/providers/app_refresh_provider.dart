import 'package:flutter/foundation.dart';

class AppRefreshProvider extends ChangeNotifier {
  int _dashboardTick = 0;
  int _prestamosTick = 0;
  int _clientesTick = 0;
  int _cobradoresTick = 0;
  int _gastosTick = 0;

  int get dashboardTick => _dashboardTick;
  int get prestamosTick => _prestamosTick;
  int get clientesTick => _clientesTick;
  int get cobradoresTick => _cobradoresTick;
  int get gastosTick => _gastosTick;

  void refreshDashboard() {
    _dashboardTick++;
    notifyListeners();
  }

  void refreshPrestamos() {
    _prestamosTick++;
    notifyListeners();
  }

  void refreshClientes() {
    _clientesTick++;
    notifyListeners();
  }

  void refreshCobradores() {
    _cobradoresTick++;
    notifyListeners();
  }

  void refreshGastos() {
    _gastosTick++;
    notifyListeners();
  }

  void refreshAll() {
    _dashboardTick++;
    _prestamosTick++;
    _clientesTick++;
    _cobradoresTick++;
    _gastosTick++;
    notifyListeners();
  }
}