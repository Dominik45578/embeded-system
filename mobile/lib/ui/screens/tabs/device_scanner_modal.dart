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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DeviceScannerModal(),
    );
  }

  @override
  State<DeviceScannerModal> createState() => _DeviceScannerModalState();
}

class _DeviceScannerModalState extends State<DeviceScannerModal> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  List<BluetoothDevice> _connectedDevices = [];
  List<BluetoothDevice> _bondedDevices = []; // Sparowane w systemie
  final BleDeviceManager _manager = BleDeviceManager();

  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<bool>? _isScanningSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  @override
  void initState() {
    super.initState();
    _initBluetoothLifecycle();
  }

  void _initBluetoothLifecycle() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() => _adapterState = state);
        if (state == BluetoothAdapterState.on) {
          _fetchConnectedAndBondedDevices();
          _startScan();
        }
      }
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) {
        setState(() => _isScanning = scanning);
      }
    });

    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() => _scanResults = results);
      }
    });
  }

  Future<void> _fetchConnectedAndBondedDevices() async {
    try {
      final connected = FlutterBluePlus.connectedDevices;
      List<BluetoothDevice> systemBonded = [];

      try {
        systemBonded = await FlutterBluePlus.systemDevices([]);
      } catch (e) {
        debugPrint('Nie można pobrać sparowanych urządzeń z systemu: $e');
      }

      if (!mounted) return;

      setState(() {
        _connectedDevices = connected;
        _bondedDevices = systemBonded
            .where((device) => !_manager.savedDevices.any((d) => d.id == device.remoteId.str))
            .toList();
      });
    } catch (e) {
      debugPrint('[DeviceScannerModal] Błąd pobierania aktywnych/sparowanych połączeń: $e');
    }
  }

  Future<void> _startScan() async {
    if (_adapterState != BluetoothAdapterState.on) {
      if (Platform.isAndroid && _adapterState == BluetoothAdapterState.off) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          _showSnackBar('Nie udało się automatycznie włączyć adaptera Bluetooth.');
        }
      }
      return;
    }

    await _fetchConnectedAndBondedDevices();

    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: false,
      );
    } catch (e) {
      _showSnackBar('Nie udało się zainicjalizować skanowania: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF1E1E1E)),
    );
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget modalContent;

    if (_adapterState == BluetoothAdapterState.unauthorized) {
      modalContent = _buildPermissionErrorView();
    } else if (_adapterState == BluetoothAdapterState.off) {
      modalContent = _buildBluetoothOffView();
    } else {
      modalContent = _buildDeviceListView();
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wyszukiwanie zamków...',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              if (!_isScanning)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF00ADB5)),
                  onPressed: _startScan,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                color: Color(0xFF00ADB5),
                backgroundColor: Colors.white10,
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: modalContent),
        ],
      ),
    );
  }

  Widget _buildPermissionErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gpp_bad_outlined, color: Colors.amber, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Brak wymaganych uprawnień',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'System operacyjny zablokował dostęp do usług bezprzewodowych. Nadaj uprawnienia do Bluetooth oraz Lokalizacji w ustawieniach telefonu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ADB5),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _startScan,
              icon: const Icon(Icons.security, color: Colors.white),
              label: const Text('Autoryzuj ponownie', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothOffView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, color: Color(0xFF00ADB5), size: 56),
            const SizedBox(height: 16),
            const Text(
              'Bluetooth jest wyłączony',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Włącz komunikację Bluetooth w systemie, aby aplikacja mogła wykryć i zarządzać zamkami.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ADB5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  try {
                    await FlutterBluePlus.turnOn();
                  } catch (e) {
                    _showSnackBar('System zablokował automatyczne włączenie. Uruchom BT ręcznie.');
                  }
                },
                icon: const Icon(Icons.bluetooth, color: Colors.white),
                label: const Text('Włącz automatycznie', style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceListView() {
    final connectedIds = _connectedDevices.map((d) => d.remoteId.str).toSet();
    final bondedIds = _bondedDevices.map((d) => d.remoteId.str).toSet();

    final discoveredResults = _scanResults
        .where((result) => 
            !connectedIds.contains(result.device.remoteId.str) && 
            !bondedIds.contains(result.device.remoteId.str))
        .toList();

    if (_connectedDevices.isEmpty && discoveredResults.isEmpty && _bondedDevices.isEmpty && !_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.radar, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Nie wykryto żadnych urządzeń',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh, color: Color(0xFF00ADB5)),
              label: const Text('Skanuj ponownie', style: TextStyle(color: Color(0xFF00ADB5))),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Sugerowane - systemowo sparowane, których nie ma w aplikacji
        if (_bondedDevices.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Zapisane w telefonie (Sugerowane)',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          ..._bondedDevices.map((device) => _buildDeviceTile(
            device: device,
            iconColor: Colors.orangeAccent,
            backgroundColor: Colors.white10,
          )),
          const SizedBox(height: 16),
        ],

        if (_connectedDevices.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Aktualnie połączone',
              style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          ..._connectedDevices.map((device) => _buildConnectedDeviceTile(device)),
          const SizedBox(height: 16),
        ],

        if (discoveredResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Dostępne w zasięgu (Wszystkie)',
              style: TextStyle(color: Color(0xFF00ADB5), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          ...discoveredResults.map((result) => _buildDeviceTile(
            device: result.device,
            iconColor: const Color(0xFF00ADB5),
            backgroundColor: Colors.white10,
          )),
        ],
      ],
    );
  }

  Widget _buildConnectedDeviceTile(BluetoothDevice device) {
    final name = device.platformName.isNotEmpty ? device.platformName : "Nieznane urządzenie";
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Colors.green,
        radius: 18,
        child: Icon(Icons.bluetooth_connected, color: Colors.white, size: 20),
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text(device.remoteId.str, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
        ),
        onPressed: () async {
          FlutterBluePlus.stopScan();
          await _manager.saveAndConnectDevice(device);
          if (mounted) Navigator.pop(context);
        },
        child: const Text('Dodaj', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDeviceTile({required BluetoothDevice device, required Color iconColor, required Color backgroundColor}) {
    final name = device.platformName.isNotEmpty ? device.platformName : "Urządzenie centralne";
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: backgroundColor,
        radius: 18,
        child: Icon(Icons.bluetooth, color: iconColor, size: 20),
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text(device.remoteId.str, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00ADB5),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
        ),
        onPressed: () async {
          FlutterBluePlus.stopScan();
          await _manager.saveAndConnectDevice(device);
          if (mounted) Navigator.pop(context);
        },
        child: const Text('Dodaj', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}