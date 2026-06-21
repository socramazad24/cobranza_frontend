// lib/screens/detalle_prestamo_screen.dart
import 'package:flutter/material.dart';

class DetallePrestamoScreen extends StatelessWidget {
  const DetallePrestamoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CRÉDITO FÁCIL', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFCCBC), // Salmón pastel
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFFBE9E7),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Botón de regreso
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                label: const Text('Regresar', style: TextStyle(color: Colors.black87)),
              ),
            ),
            const Text('Active Loans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Client Name', style: TextStyle(color: Colors.grey)),
                    const Text('María Gómez', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    const Text('Loan Amount', style: TextStyle(color: Colors.grey)),
                    const Text('\$600,000', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Start Date', style: TextStyle(color: Colors.grey)),
                        Text('End Date', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('01 Jan 2024', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('01 Mar 2024', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFAB91),
                        ),
                        child: const Text('Renew Debt'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return const ListTile(
                    title: Text('Payment History', style: TextStyle(fontSize: 14)),
                    subtitle: Text('01 Jan 2024', style: TextStyle(fontSize: 12)),
                    trailing: Text('\$35.00', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}