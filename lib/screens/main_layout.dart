// lib/screens/main_layout.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reportes_screen.dart';
import 'clientes_screen.dart';      // ← NUEVO
import 'prestamos_screen.dart';
import 'cobradores_screen.dart';
import 'gastos_screen.dart';
import 'clavos_screen.dart';
import 'admin_panel_screen.dart';
import 'login_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  String _rol    = 'cobrador';
  String _nombre = '';

  // ✅ Ahora 6 colores — uno por cada tab
  final List<Color> _coloresAppBar = [
    const Color(0xFFB3E5FC), // Dashboard
    const Color(0xFFE8F5E9), // Clientes  ← NUEVO
    const Color(0xFFFFCCBC), // Préstamos
    const Color(0xFFB9F6CA), // Cobradores
    const Color(0xFFE1BEE7), // Gastos
    const Color(0xFFFFCDD2), // Clavos
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rol    = prefs.getString('user_rol')    ?? 'cobrador';
      _nombre = prefs.getString('user_nombre') ?? 'Usuario';
    });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = _rol == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRÉDITO FÁCIL',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _coloresAppBar[_currentIndex],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                color: const Color(0xFFB3E5FC),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(
                        esAdmin ? Icons.admin_panel_settings : Icons.person,
                        size: 35,
                        color: esAdmin ? Colors.indigo : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_nombre,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: esAdmin ? Colors.indigo : Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        esAdmin ? 'Administrador' : 'Cobrador',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ✅ Drawer — índices actualizados
              _drawerItem(Icons.home,                  'Dashboard',         Colors.blue,   0),
              _drawerItem(Icons.people,                'Clientes',          Colors.teal,   1), // ← NUEVO
              _drawerItem(Icons.receipt_long,          'Préstamos',         Colors.orange, 2), // ← era 1
              _drawerItem(Icons.motorcycle,            'Cobradores',        Colors.green,  3), // ← era 2
              _drawerItem(Icons.savings,               'Gastos Diarios',    Colors.purple, 4), // ← era 3
              _drawerItem(Icons.warning_amber_rounded, 'Clavos (Morosos)',  Colors.red,    5), // ← era 4

              const Divider(),

              if (esAdmin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings,
                      color: Colors.indigo),
                  title: const Text('Panel Administrador',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdminPanelScreen()),
                    );
                  },
                ),

              const Spacer(),
              const Divider(),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cerrar Sesión'),
                      content: const Text('¿Estás seguro de que quieres salir?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _logout();
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Salir',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),

      // ✅ IndexedStack — ahora con 6 screens
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ReportesScreen(),   // 0 - Dashboard
          ClientesScreen(),   // 1 - Clientes   ← NUEVO
          PrestamosScreen(),  // 2 - Préstamos
          CobradoresScreen(), // 3 - Cobradores
          GastosScreen(),     // 4 - Gastos
          ClavosScreen(),     // 5 - Clavos
        ],
      ),

      // ✅ BottomBar — ahora con 6 items
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),                  label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people),                label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long),          label: 'Préstamos'),
          BottomNavigationBarItem(icon: Icon(Icons.motorcycle),            label: 'Cobradores'),
          BottomNavigationBarItem(icon: Icon(Icons.savings),               label: 'Gastos'),
          BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: 'Clavos'),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, Color color, int index) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : Colors.black87)),
      tileColor: isSelected ? color.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
    );
  }
}