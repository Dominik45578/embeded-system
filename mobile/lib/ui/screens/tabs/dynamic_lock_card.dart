import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/model/lock_command.dart';
import '../../../core/services/ble/ble_device_manger.dart';
import '../../../core/services/ble/ble_lock_connection.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';

class DynamicLockCard extends StatelessWidget {
  final String deviceId;
  const DynamicLockCard({super.key, required this.deviceId});

  void _showInfoPanel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Informacje o urządzeniu', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAC / ID: $deviceId', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('Konfiguracja Wi-Fi (wkrótce)', style: TextStyle(color: Colors.white70)),
            const Text('Adres brokera MQTT (wkrótce)', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij', style: TextStyle(color: Color(0xFF00ADB5))),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnlock(BuildContext context, BleLockConnection connection) async {
    final pin = await _showInputDialog(context, 'Wprowadź PIN', 'PIN', false);
    if (pin != null && pin.isNotEmpty) {
      // Budowa komendy UNLOCK:<pin> zgodnie z logiką firmware
      await connection.sendCommand(LockCommand(LockCommandType.unlock, [pin]));
    }
  }

  Future<void> _handleChangePin(BuildContext context, BleLockConnection connection) async {
    final oldPin = await _showInputDialog(context, 'Podaj obecny PIN', 'Stary PIN', false);
    if (oldPin == null || oldPin.isEmpty) return;

    final newPin = await _showInputDialog(context, 'Podaj nowy PIN', 'Nowy PIN', false);
    if (newPin != null && newPin.isNotEmpty) {
      // Budowa komendy CHANGE:<old_pin>:<new_pin>
      await connection.sendCommand(LockCommand(LockCommandType.changePin, [oldPin, newPin]));
    }
  }

  Future<String?> _showInputDialog(BuildContext context, String title, String hint, bool isPassword) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          obscureText: isPassword,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Zatwierdź', style: TextStyle(color: Color(0xFF00ADB5))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = BleDeviceManager();
    final connection = manager.getConnection(deviceId);

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lockly Smart Lock', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  StreamBuilder<BluetoothConnectionState>(
                    stream: connection?.connectionStateStream,
                    initialData: BluetoothConnectionState.disconnected,
                    builder: (context, snapshot) {
                      final isConnected = snapshot.data == BluetoothConnectionState.connected;
                      return Icon(
                        isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: isConnected ? const Color(0xFF00ADB5) : Colors.red,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.grey),
                    onPressed: () => _showInfoPanel(context),
                  ),
                ],
              )
            ],
          ),
          
          if (connection != null)
            StreamBuilder<String>(
              stream: connection.lockStateStream,
              initialData: 'Pobieranie statusu...',
              builder: (context, snapshot) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Status: ${snapshot.data}', style: const TextStyle(color: Colors.amber)),
              ),
            ),
            
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Otwórz',
                  icon: Icons.lock_open_rounded,
                  onPressed: connection == null ? () {} : () => _handleUnlock(context, connection),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Zamknij',
                  icon: Icons.lock_rounded,
                  type: CustomButtonType.secondary,
                  // Komenda LOCK nie wymaga argumentów w firmware
                  onPressed: connection == null ? () {} : () => connection.sendCommand(LockCommand(LockCommandType.lock)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Zmień PIN urządzenia',
            icon: Icons.password_rounded,
            type: CustomButtonType.secondary,
            isFullWidth: true,
            onPressed: connection == null ? () {} : () => _handleChangePin(context, connection),
          ),
        ],
      ),
    );
  }
}