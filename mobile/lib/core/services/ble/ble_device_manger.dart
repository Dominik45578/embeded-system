import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../model/lock_command.dart';
import 'ble_lock_connection.dart';

class BleDeviceManager extends ChangeNotifier {
  static final BleDeviceManager _instance = BleDeviceManager._internal();
  factory BleDeviceManager() => _instance;
  BleDeviceManager._internal();

  static const String _storageKey = 'bonded_ble_devices';

  // Słownik aktywnych obiektów sesji sesji połączeń
  final Map<String, BleLockConnection> _activeConnections = {};
  
  // Lista identyfikatorów (MAC adresów) trwale zapisanych w pamięci urządzenia
  List<String> _savedDeviceIds = [];

  List<String> get savedDeviceIds => _savedDeviceIds;

  /// Inicjalizacja managera – wywołaj ją przy starcie aplikacji (np. w main.dart)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _savedDeviceIds = prefs.getStringList(_storageKey) ?? [];
    notifyListeners();
  }

  BleLockConnection? getConnection(String deviceId) => _activeConnections[deviceId];

  bool isConnected(String deviceId) => _activeConnections.containsKey(deviceId);

  /// Zapisywanie nowego zamka z poziomu UI (Dodawanie urządzenia)
  Future<void> saveAndConnectDevice(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    if (!_savedDeviceIds.contains(deviceId)) {
      _savedDeviceIds.add(deviceId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, _savedDeviceIds);
    }

    // Automatyczne nawiązanie połączenia po dodaniu
    await connectToDevice(device);
    notifyListeners();
  }

  /// Usuwanie urządzenia z pamięci i rozłączenie
  Future<void> forgetDevice(String deviceId) async {
    await disconnectDevice(deviceId);
    _savedDeviceIds.remove(deviceId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _savedDeviceIds);
    notifyListeners();
  }

  Future<BleLockConnection> connectToDevice(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    
    if (_activeConnections.containsKey(deviceId)) {
      return _activeConnections[deviceId]!;
    }

    final connection = BleLockConnection(device);
    await connection.connect();
    
    _activeConnections[deviceId] = connection;
    notifyListeners(); // UI dowiaduje się, że status uległ zmianie na "Połączony"
    return connection;
  }

  Future<void> disconnectDevice(String deviceId) async {
    final connection = _activeConnections.remove(deviceId);
    if (connection != null) {
      await connection.disconnect();
      notifyListeners(); // UI dowiaduje się o rozłączeniu
    }
  }

  Future<void> setLockCommand(String deviceId, LockCommand command) async {
    final connection = getConnection(deviceId);
    if (connection != null) {
      await connection.sendCommand(command);
    } else {
      throw Exception('Urządzenie $deviceId nie jest połączone.');
    }
  }
}