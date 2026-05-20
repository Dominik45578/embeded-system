import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../model/device.dart';
import '../../model/device_event.dart';
import '../../model/lock_command.dart';
import '../database_service.dart';
import 'ble_lock_connection.dart';

class BleDeviceManager extends ChangeNotifier {
  static final BleDeviceManager _instance = BleDeviceManager._internal();
  factory BleDeviceManager() => _instance;
  BleDeviceManager._internal();

  final List<DeviceEvent> _events = [];
  List<DeviceEvent> get events => List.unmodifiable(_events);

  bool _hasMoreEvents = true;
  bool get hasMoreEvents => _hasMoreEvents;

  final DatabaseService _dbService = DatabaseService.instance;
  final Map<String, StreamSubscription> _streamSubscriptions = {};

  final Map<String, BleLockConnection> _activeConnections = {};
  
  List<Device> _savedDevices = [];

  List<Device> get savedDevices => _savedDevices;

  Future<void> init() async {
    _savedDevices = await _dbService.getSavedDevices();
    await fetchNextEventsPage(isRefresh: true);
    await reconnectToSavedDevices();
    notifyListeners();
  }

  Future<void> reconnectToSavedDevices() async {
    // 1. Sprawdź, które urządzenia są już połączone na poziomie systemu
    List<BluetoothDevice> systemConnectedDevices = FlutterBluePlus.connectedDevices;
    
    for (final device in _savedDevices) {
      if (isConnected(device.id)) continue;

      try {
        final bleDevice = BluetoothDevice.fromId(device.id);
        
        // 2. Jeśli urządzenie jest na liście systemowych połączeń, pomiń fizyczne nawiązywanie połączenia
        bool isAlreadySystemConnected = systemConnectedDevices.any((d) => d.remoteId.str == device.id);
        
        if (isAlreadySystemConnected) {
          debugPrint('Urządzenie ${device.id} jest już połączone systemowo. Przejmowanie połączenia...');
          await _setupExistingConnection(bleDevice);
        } else {
          debugPrint('Próba nowego połączenia z ${device.id}...');
          // Ustawiamy krótki timeout, aby uniknąć blokowania UI na długo
          await connectToDevice(bleDevice).timeout(const Duration(seconds: 10));
        }
      } catch (e) {
        debugPrint('Nie udało się automatycznie połączyć/zainicjować ${device.id}: $e');
        await _dbService.updateDeviceConnectionState(device.id, false);
      }
    }
    notifyListeners();
  }

  // Ustawia połączenie dla urządzenia, z którym telefon jest już połączony na poziomie OS
  Future<BleLockConnection> _setupExistingConnection(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    
    final connection = BleLockConnection(device);
    // POMIJAMY connection.connect() ponieważ wystąpiłby GATT_INVALID_HANDLE
    await connection.discoverServicesAndSetup(); 
    
    await _registerConnection(deviceId, connection);
    return connection;
  }

  Future<void> saveAndConnectDevice(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    if (!_savedDevices.any((d) => d.id == deviceId)) {
      final newDevice = Device(id: deviceId, name: device.platformName, isBlocked: false);
      _savedDevices.add(newDevice);
      await _dbService.insertDevice(newDevice);
    }

    await connectToDevice(device);
    notifyListeners();
  }

  Future<void> forgetDevice(String deviceId) async {
    await disconnectDevice(deviceId);
    _savedDevices.removeWhere((d) => d.id == deviceId);
    await _dbService.deleteDevice(deviceId);
    notifyListeners();
  }

  Future<BleLockConnection> connectToDevice(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;

    if (_activeConnections.containsKey(deviceId)) {
      return _activeConnections[deviceId]!;
    }

    final connection = BleLockConnection(device);
    await connection.connect();
    await connection.discoverServicesAndSetup();

    await _registerConnection(deviceId, connection);
    return connection;
  }
  
  Future<void> _registerConnection(String deviceId, BleLockConnection connection) async {
    await _dbService.updateDeviceConnectionState(deviceId, true);
    _activeConnections[deviceId] = connection;

    _streamSubscriptions[deviceId] = connection.lockStateStream.listen((rawMessage) {
      logEvent(rawMessage, EventSource.bluetooth);
    });
    
    // Nasłuchiwanie rozłączeń z zewnątrz
    connection.connectionStateStream.listen((state) {
        if(state == BluetoothConnectionState.disconnected) {
            debugPrint('Urządzenie $deviceId zostało rozłączone.');
            _handleDeviceDisconnected(deviceId);
        }
    });

    notifyListeners();
  }

  Future<void> disconnectDevice(String deviceId) async {
    final connection = _activeConnections[deviceId];
    if (connection != null) {
      await connection.disconnect();
      _handleDeviceDisconnected(deviceId);
    }
  }
  
  void _handleDeviceDisconnected(String deviceId) {
      _activeConnections.remove(deviceId);
      _streamSubscriptions[deviceId]?.cancel();
      _streamSubscriptions.remove(deviceId);
      _dbService.updateDeviceConnectionState(deviceId, false);
      notifyListeners();
  }

  BleLockConnection? getConnection(String deviceId) => _activeConnections[deviceId];

  bool isConnected(String deviceId) => _activeConnections.containsKey(deviceId);

  Future<void> setLockCommand(String deviceId, LockCommand command) async {
    final connection = getConnection(deviceId);
    if (connection != null) {
      await connection.sendCommand(command);
    } else {
      throw Exception('Urządzenie $deviceId nie jest połączone.');
    }
  }

  Future<void> fetchNextEventsPage({bool isRefresh = false}) async {
    if (isRefresh) {
      _events.clear();
      _hasMoreEvents = true;
    }

    if (!_hasMoreEvents) return;

    final int currentOffset = _events.length;
    final List<DeviceEvent> newPage = await _dbService.getPagedEvents(20, currentOffset);

    if (newPage.length < 20) {
      _hasMoreEvents = false;
    }

    _events.addAll(newPage);
    notifyListeners();
  }

  Future<void> logEvent(String message, EventSource source) async {
    final newEvent = DeviceEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      message: message,
      timestamp: DateTime.now(),
      source: source,
    );

    await _dbService.insertEvent(newEvent);
    _events.insert(0, newEvent);
    notifyListeners();
  }
}