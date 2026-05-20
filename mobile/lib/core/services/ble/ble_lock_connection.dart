import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../model/lock_command.dart';

class BleLockConnection {
  final BluetoothDevice _device;

  // FF20 Service
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  // FF30 Service
  BluetoothCharacteristic? _deviceIdChar;

  // FF40 Service
  BluetoothCharacteristic? _wifiReadChar;
  BluetoothCharacteristic? _wifiWriteChar;
  BluetoothCharacteristic? _mqttReadChar;
  BluetoothCharacteristic? _mqttWriteChar;
  BluetoothCharacteristic? _configStateChar;


  final StreamController<String> _stateController = StreamController<String>.broadcast();
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  BleLockConnection(this._device);

  Stream<String> get lockStateStream => _stateController.stream;

  Stream<BluetoothConnectionState> get connectionStateStream => _device.connectionState;

  String getDeviceId() => _device.remoteId.str;

  // Krok 1: Fizyczne połączenie i parowanie
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
  }

  // Krok 2: Odkrycie usług i konfiguracja (może być wywołane dla już połączonego urządzenia)
  Future<void> discoverServicesAndSetup() async {
    try {
      await _device.requestMtu(512).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[BLE] Negocjacja MTU nieudana: $e. Kontynuacja z domyślnym MTU.');
    }

    final services = await _device.discoverServices();
    for (var service in services) {
      // Serwis FF20 - Sterowanie zamkiem
      if (service.uuid == Guid("FF20")) {
        for (var char in service.characteristics) {
          if (char.uuid == Guid("FF21")) _writeChar = char;
          if (char.uuid == Guid("FF22")) {
            _notifyChar = char;
            await _setupNotifications();
          }
        }
      }
      // Serwis FF30 - Identyfikacja urządzenia
      else if (service.uuid == Guid("FF30")) {
        for (var char in service.characteristics) {
          if (char.uuid == Guid("FF31")) _deviceIdChar = char;
        }
      }
      // Serwis FF40 - Konfiguracja
      else if (service.uuid == Guid("FF40")) {
        for (var char in service.characteristics) {
          if (char.uuid == Guid("FF41")) _wifiReadChar = char;
          if (char.uuid == Guid("FF42")) _wifiWriteChar = char;
          if (char.uuid == Guid("FF43")) _mqttReadChar = char;
          if (char.uuid == Guid("FF44")) _mqttWriteChar = char;
          if (char.uuid == Guid("FF45")) _configStateChar = char;
        }
      }
    }
  }

  Future<void> disconnect() async {
    await _connectionStateSubscription?.cancel();
    await _notifySubscription?.cancel();
    await _stateController.close();
    await _device.disconnect();
  }

  Future<void> sendCommand(LockCommand command) async {
    if (_writeChar == null) throw Exception('Brak charakterystyki zapisu FF21.');
    final bytes = utf8.encode(command.toPayload());
    await _writeChar!.write(bytes, withoutResponse: false);
  }

  Future<String> readDeviceId() async {
    if (_deviceIdChar == null) throw Exception('Brak charakterystyki odczytu ID urządzenia FF31.');
    final value = await _deviceIdChar!.read();
    return utf8.decode(value);
  }

  Future<String> readWifiSsid() async {
    if (_wifiReadChar == null) throw Exception('Brak charakterystyki odczytu Wi-Fi FF41.');
    final value = await _wifiReadChar!.read();
    return utf8.decode(value);
  }

  Future<void> writeWifiCredentials(String ssid, String password) async {
    if (_wifiWriteChar == null) throw Exception('Brak charakterystyki zapisu Wi-Fi FF42.');
    if (_configStateChar == null) throw Exception('Brak charakterystyki stanu konfiguracji FF45.');

    await _configStateChar!.write([1]);
    await _wifiWriteChar!.write(utf8.encode(ssid));
    await _wifiWriteChar!.write(utf8.encode(password));
    await _configStateChar!.write([2]);
  }

  Future<Map<String, String>> readMqttConfig() async {
    if (_mqttReadChar == null) throw Exception('Brak charakterystyki odczytu MQTT FF43.');
    final value = await _mqttReadChar!.read();
    final parts = utf8.decode(value).split(',');
    if (parts.length == 2) {
      return {'broker': parts[0], 'topic': parts[1]};
    }
    return {'broker': '', 'topic': ''};
  }

  Future<void> writeMqttConfig(String broker, String topic) async {
    if (_mqttWriteChar == null) throw Exception('Brak charakterystyki zapisu MQTT FF44.');
    if (_configStateChar == null) throw Exception('Brak charakterystyki stanu konfiguracji FF45.');

    await _configStateChar!.write([3]);
    await _mqttWriteChar!.write(utf8.encode('$broker,$topic'));
    await _configStateChar!.write([4]);
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