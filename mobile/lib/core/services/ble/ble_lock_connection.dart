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
  BluetoothCharacteristic? _wifiReadChar; // FF41 (legacy)
  BluetoothCharacteristic? _wifiWriteChar; // FF42
  BluetoothCharacteristic? _mqttReadChar; // FF43 (legacy)
  BluetoothCharacteristic? _mqttWriteChar; // FF44
  BluetoothCharacteristic? _configStateChar; // FF45
  BluetoothCharacteristic? _configJsonChar; // FF46 (new JSON)

  final StreamController<String> _stateController = StreamController<String>.broadcast();
  StreamSubscription<List<int>>? _notifySubscription;

  BleLockConnection(this._device);

  Stream<String> get lockStateStream => _stateController.stream;

  Stream<BluetoothConnectionState> get connectionStateStream => _device.connectionState;

  String getDeviceId() => _device.remoteId.str;

  // Krok 1: Fizyczne połączenie i parowanie
  Future<void> connect() async {
    // Wracamy do autoConnect: false, aby uniknąć konfliktów systemowych
    await _device.connect(autoConnect: false, license: License.free);

    // Aby wysyłać wiadomości dłuższe niż 20 bajtów (np. MQTT 'broker,topic'),
    // próbujemy wynegocjować wyższe MTU. Robimy to w bloku try/catch, 
    // aby nie przerywało połączenia w przypadku problemów z konkretnym stosem BLE.
    try {
      await _device.requestMtu(512);
      debugPrint('[BLE] MTU wynegocjowane pomyślnie.');
    } catch (e) {
      debugPrint('[BLE] Ostrzeżenie: Negocjacja MTU nie powiodła się: $e');
    }

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
      // Serwis FF40 - Konfiguracja sieciowa
      else if (service.uuid == Guid("FF40")) {
        for (var char in service.characteristics) {
          if (char.uuid == Guid("FF41")) _wifiReadChar = char;
          if (char.uuid == Guid("FF42")) _wifiWriteChar = char;
          if (char.uuid == Guid("FF43")) _mqttReadChar = char;
          if (char.uuid == Guid("FF44")) _mqttWriteChar = char;
          if (char.uuid == Guid("FF45")) _configStateChar = char;
          if (char.uuid == Guid("FF46")) _configJsonChar = char;
        }
      }
    }
  }

  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    await _stateController.close();
    await _device.disconnect();
  }

  Future<void> performKeepAlive() async {
    try {
      await _device.readRssi();
      debugPrint('[BLE Keep-Alive] Odczytano RSSI dla ${getDeviceId()}');
    } catch (e) {
      debugPrint('[BLE Keep-Alive] Błąd podczas odczytu RSSI: $e');
      // Błąd może oznaczać, że połączenie zostało zerwane. Manager to obsłuży.
    }
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

  // --- Nowa logika konfiguracji oparta na nowym firmware ---

  Future<Map<String, dynamic>> readConfigJson() async {
    if (_configJsonChar == null) throw Exception('Brak charakterystyki odczytu JSON FF46.');
    final value = await _configJsonChar!.read();
    final jsonString = utf8.decode(value);
    
    if (jsonString.isEmpty) {
        return {};
    }
    
    try {
        return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
        debugPrint('[BLE] Błąd parsowania JSON z FF46: $e');
        return {};
    }
  }

  Future<void> writeWifiCredentials(String ssid, String password) async {
    if (_wifiWriteChar == null) throw Exception('Brak charakterystyki zapisu Wi-Fi FF42.');
    if (_configStateChar == null) throw Exception('Brak charakterystyki stanu konfiguracji FF45.');

    await _configStateChar!.write([1], withoutResponse: false);
    await Future.delayed(const Duration(milliseconds: 100)); 
    
    await _wifiWriteChar!.write(utf8.encode(ssid), withoutResponse: false);
    await Future.delayed(const Duration(milliseconds: 100));
    
    await _wifiWriteChar!.write(utf8.encode(password), withoutResponse: false);
    await Future.delayed(const Duration(milliseconds: 100));
    
    await _configStateChar!.write([2], withoutResponse: false);
  }

  Future<void> writeMqttConfig(String broker, String topic) async {
    if (_mqttWriteChar == null) throw Exception('Brak charakterystyki zapisu MQTT FF44.');
    if (_configStateChar == null) throw Exception('Brak charakterystyki stanu konfiguracji FF45.');

    await _configStateChar!.write([3], withoutResponse: false);
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Zgodnie ze specyfikacją ESP32 wysyłamy format 'broker,topic'
    final mqttCombined = '$broker,$topic';
    
    // allowLongWrite: true zapobiega problemom przy braku MTU dla payloadu >20 bajtów
    await _mqttWriteChar!.write(utf8.encode(mqttCombined), withoutResponse: false, allowLongWrite: true);
    await Future.delayed(const Duration(milliseconds: 100));
    
    await _configStateChar!.write([4], withoutResponse: false);
  }

  Future<void> rebootDevice() async {
      if (_configStateChar == null) throw Exception('Brak charakterystyki stanu konfiguracji FF45.');
      await _configStateChar!.write([5], withoutResponse: false);
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