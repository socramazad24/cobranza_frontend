import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkAwareWidget extends StatefulWidget {
  final Widget child;
  const NetworkAwareWidget({super.key, required this.child});

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  bool _sinConexion = false;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((results) {
      final sinRed = results.every((r) => r == ConnectivityResult.none);
      if (mounted) setState(() => _sinConexion = sinRed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_sinConexion)
          Container(
            width: double.infinity,
            color: Colors.red[700],
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Sin conexión a internet',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}