import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/model/device.dart';
import '../../../core/model/lock_command.dart';
import '../../../core/services/ble/ble_device_manger.dart';
import '../../../core/services/ble/ble_lock_connection.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';
import 'device_settings_sheet.dart';

class DynamicLockCard extends StatefulWidget {
  final Device device;

  const DynamicLockCard({super.key, required this.device});

  @override
  State<DynamicLockCard> createState() => _DynamicLockCardState();
}

class _DynamicLockCardState extends State<DynamicLockCard> {
  final BleDeviceManager _bleManager = BleDeviceManager();
  bool _isConnecting = false;

  Future<void> _connectToDevice() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      final bleDevice = BluetoothDevice.fromId(widget.device.id);
      await _bleManager.connectToDevice(bleDevice);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd połączenia: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _handleUnlock(BuildContext context, BleLockConnection connection) async {
    final pin = await _showInputDialog(context, 'Wprowadź PIN', 'PIN');
    if (pin != null && pin.isNotEmpty) {
      await connection.sendCommand(LockCommand(LockCommandType.unlock, [pin]));
    }
  }

  Future<void> _handleChangePin(BuildContext context, BleLockConnection connection) async {
    final oldPin = await _showInputDialog(context, 'Podaj obecny PIN', 'Stary PIN');
    if (oldPin == null || oldPin.isEmpty) return;

    final newPin = await _showInputDialog(context, 'Podaj nowy PIN', 'Nowy PIN');
    if (newPin != null && newPin.isNotEmpty) {
      await connection.sendCommand(LockCommand(LockCommandType.changePin, [oldPin, newPin]));
    }
  }

  Future<String?> _showInputDialog(BuildContext context, String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Zatwierdź', style: TextStyle(color: Color(0xFF00ADB5)))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _bleManager,
      builder: (context, child) {
        final connection = _bleManager.getConnection(widget.device.id);
        final isConnected = _bleManager.isConnected(widget.device.id);

        return CustomCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.device.name.isNotEmpty ? widget.device.name : 'Zamek bez nazwy',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.bluetooth, color: isConnected ? const Color(0xFF00ADB5) : Colors.grey),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.grey),
                        onPressed: () => DeviceSettingsSheet.show(context, widget.device),
                      ),
                    ],
                  )
                ],
              ),

              if (!isConnected)
                _buildConnectionControls()
              else if (connection != null)
                _buildStatusStream(connection)
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Status: Inicjalizacja...', style: TextStyle(color: Colors.amber)),
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Otwórz',
                      icon: Icons.lock_open_rounded,
                      onPressed: () {
                        if (isConnected && connection != null) {
                          _handleUnlock(context, connection);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Zamknij',
                      icon: Icons.lock_rounded,
                      type: CustomButtonType.secondary,
                      onPressed: () {
                        if (isConnected && connection != null) {
                          connection.sendCommand(LockCommand(LockCommandType.lock));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Zmień PIN',
                icon: Icons.password_rounded,
                type: CustomButtonType.secondary,
                isFullWidth: true,
                onPressed: () {
                  if (isConnected && connection != null) {
                    _handleChangePin(context, connection);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Rozłączony', style: TextStyle(color: Colors.white.withOpacity(0.6))),
          if (_isConnecting)
            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00ADB5)))
          else
            TextButton(
              onPressed: _connectToDevice,
              child: const Text('Połącz', style: TextStyle(color: Color(0xFF00ADB5), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusStream(BleLockConnection connection) {
    return StreamBuilder<String>(
      stream: connection.lockStateStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Status: Połączono, oczekiwanie na dane...', style: TextStyle(color: Colors.amber)),
          );
        }

        String displayStatus = snapshot.data ?? 'Brak danych';
        Color statusColor = Colors.grey;

        if (snapshot.hasData) {
          if (displayStatus.contains('UNLOCKED')) {
            displayStatus = 'Zamek otwarty';
            statusColor = Colors.green;
          } else if (displayStatus.contains('LOCKED')) {
            displayStatus = 'Zamek zamknięty';
            statusColor = Colors.red;
          } else if (displayStatus.contains('PIN_CHANGED')) {
            displayStatus = 'Zmieniono PIN';
            statusColor = Colors.orange;
          } else {
            statusColor = Colors.amber;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Status: $displayStatus', style: TextStyle(color: statusColor)),
        );
      },
    );
  }
}