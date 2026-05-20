import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../model/lock_command.dart';

class BleLockConnection {
  final BluetoothDevice _device;

  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  final StreamController<String> _stateController = StreamController<String>.broadcast();
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BleLockConnection(this._device);

  Stream<String> get lockStateStream => _stateController.stream;

  Stream<BluetoothConnectionState> get connectionStateStream => _device.connectionState;

  String getDeviceId() => _device.remoteId.str;

  Future<void> connect() async {
    await _device.connect(autoConnect: false, license: License.free);

    await Future.delayed(const Duration(milliseconds: 300));
    try {
      debugPrint('[BLE] Inicjalizacja procedury parowania/bondingu...');

      await _device.createBond();
      debugPrint('[BLE] Urządzenie pomyślnie sparowane (Bonded).');
    } catch (e) {
      debugPrint('[BLE] Ostrzeżenie podczas parowania (prawdopodobnie już sparowane): $e');
    }

    // 3. Negocjacja wielkości pakietu MTU
    try {
      await _device.requestMtu(512).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[BLE] Negocjacja MTU nieudana: $e. Kontynuacja z domyślnym MTU.');
    }

    // 4. Odkrywanie usług i rejestracja subskrypcji strumienia statusu rygla
    await _discoverServices();
  }

  Future<void> disconnect() async {
    await _connectionStateSubscription?.cancel();
    await _notifySubscription?.cancel();
    await _stateController.close();
    await _device.disconnect();
  }

  Future<void> sendCommand(LockCommand command) async {
    if (_writeChar == null) throw Exception('Brak charakterystyki zapisu.');
    final bytes = utf8.encode(command.toPayload());
    await _writeChar!.write(bytes, withoutResponse: false);
  }

  Future<void> _discoverServices() async {
    final services = await _device.discoverServices();
    for (var service in services) {
      if (service.uuid == Guid("FF20")) {
        for (var char in service.characteristics) {
          if (char.uuid == Guid("FF21")) _writeChar = char;
          if (char.uuid == Guid("FF22")) {
            _notifyChar = char;
            await _setupNotifications();
          }
        }
      }
    }
  }

  Future<void> _setupNotifications() async {
    if (_notifyChar != null) {
      await _notifyChar!.setNotifyValue(true);
      _notifySubscription = _notifyChar!.lastValueStream.listen((value) {
        if (value.isNotEmpty) {
          _stateController.add(utf8.decode(value));
        }
      });
    }
  }
}