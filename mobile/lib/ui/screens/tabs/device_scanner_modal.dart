import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/services/ble/ble_device_manger.dart';

class DeviceScannerModal extends StatefulWidget {
  const DeviceScannerModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      builder: (_) => const DeviceScannerModal(),
    );
  }

  @override
  State<DeviceScannerModal> createState() => _DeviceScannerModalState();
}

class _DeviceScannerModalState extends State<DeviceScannerModal> {
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _checkBtAndScan();
  }

  Future<void> _checkBtAndScan() async {
    // Weryfikacja stanu Bluetooth
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      } else {
        // Na iOS użytkownik musi włączyć BT ręcznie w ustawieniach
        return;
      }
    }

    setState(() => _isScanning = true);

    // Filtrowanie wyłącznie urządzeń posiadających serwis FF30
    await FlutterBluePlus.startScan(
      withServices: [Guid("FF30")], 
      timeout: const Duration(seconds: 10),
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() => _scanResults = results);
    });

    // Zatrzymanie UI po końcu skanowania
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wyszukiwanie zamków...', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_isScanning) const LinearProgressIndicator(color: Color(0xFF00ADB5)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final deviceName = result.device.platformName.isNotEmpty ? result.device.platformName : "Nieznane urządzenie";
                
                return ListTile(
                  leading: const Icon(Icons.bluetooth, color: Color(0xFF00ADB5)),
                  title: Text(deviceName, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(result.device.remoteId.str, style: const TextStyle(color: Colors.grey)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00ADB5)),
                    onPressed: () async {
                      FlutterBluePlus.stopScan();
                      // Zapis i połączenie z wykorzystaniem przygotowanego wcześniej Managera
                      await BleDeviceManager().saveAndConnectDevice(result.device);
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Połącz'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}