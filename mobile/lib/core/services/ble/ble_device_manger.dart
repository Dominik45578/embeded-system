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

  BleDeviceManager._internal() {
    _initBluetoothStateListener();
    init();
  }

  static const int _eventsPageSize = 20;

  final Map<String, BleLockConnection> _connections = {};
  final Map<String, StreamSubscription<BluetoothConnectionState>> _connectionStateSubscriptions = {};
  final Map<String, StreamSubscription<String>> _lockStateSubscriptions = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  final StreamController<List<ScanResult>> _scanResultsController = StreamController.broadcast();
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;

  final List<Device> _savedDevices = [];
  final List<DeviceEvent> _events = [];
  int _eventsOffset = 0;
  bool _hasMoreEvents = true;
  bool _isInitialized = false;

  bool isScanning = false;

  List<Device> get savedDevices => List.unmodifiable(_savedDevices);
  List<DeviceEvent> get events => List.unmodifiable(_events);
  bool get hasMoreEvents => _hasMoreEvents;

  Future<void> init() async {
    if (_isInitialized) {
      await _loadSavedDevices();
      return;
    }

    _isInitialized = true;
    await _loadSavedDevices();
    await fetchNextEventsPage(isRefresh: true);
    await reconnectToSavedDevices();
  }

  Future<void> reconnectToSavedDevices() async {
    final systemConnectedDevices = FlutterBluePlus.connectedDevices;

    for (final device in _savedDevices) {
      if (isConnected(device.id)) continue;

      try {
        final isAlreadySystemConnected = systemConnectedDevices.any((bleDevice) => bleDevice.remoteId.str == device.id);

        if (isAlreadySystemConnected) {
          final bluetoothDevice = systemConnectedDevices.firstWhere((bleDevice) => bleDevice.remoteId.str == device.id);
          await _setupExistingConnection(bluetoothDevice);
        } else {
          await connectToDevice(device.id).timeout(const Duration(seconds: 10));
        }
      } catch (e) {
        debugPrint('[BleDeviceManager] Nie udalo sie automatycznie polaczyc z ${device.id}: $e');
        await DatabaseService.instance.updateDeviceConnectionState(device.id, false);
      }
    }

    notifyListeners();
  }

  Future<void> _setupExistingConnection(BluetoothDevice device) async {
    final deviceId = device.remoteId.str;
    if (_connections.containsKey(deviceId)) return;

    final connection = BleLockConnection(device);
    await connection.discoverServicesAndSetup();
    await _registerConnection(deviceId, connection);
  }

  void _initBluetoothStateListener() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        startScan();
      } else {
        stopScan();
      }
    });
  }

  void startScan() {
    if (isScanning) return;
    isScanning = true;
    notifyListeners();

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResultsController.add(results);
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    Future.delayed(const Duration(seconds: 10), stopScan);
  }

  Future<void> stopScan() async {
    isScanning = false;
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    notifyListeners();
  }

  Future<void> _loadSavedDevices() async {
    final devices = await DatabaseService.instance.getSavedDevices();
    _savedDevices
      ..clear()
      ..addAll(devices);
    notifyListeners();
  }

  Future<void> fetchNextEventsPage({bool isRefresh = false}) async {
    if (isRefresh) {
      _eventsOffset = 0;
      _hasMoreEvents = true;
      _events.clear();
    }

    if (!_hasMoreEvents) return;

    final nextPage = await DatabaseService.instance.getPagedEvents(_eventsPageSize, _eventsOffset);
    _events.addAll(nextPage);
    _eventsOffset += nextPage.length;
    _hasMoreEvents = nextPage.length == _eventsPageSize;
    notifyListeners();
  }

  Future<void> saveAndConnectDevice(BluetoothDevice bluetoothDevice, String hardwareId) async {
    final device = Device(
      id: bluetoothDevice.remoteId.str, // Adres MAC jako kotwica BLE
      hardwareId: hardwareId,           // Hardware ID jako kotwica API
      name: bluetoothDevice.platformName.isNotEmpty ? bluetoothDevice.platformName : 'Zamek',
      isBlocked: false,
    );

    await DatabaseService.instance.insertDevice(device);
    await _loadSavedDevices();
    await connectToDevice(device.id); // Reconnect poprawnie użyje adresu MAC
  }

  Future<void> connectToDevice(String deviceId) async {
    if (_connections.containsKey(deviceId)) return;

    final device = BluetoothDevice.fromId(deviceId);
    final connection = BleLockConnection(device);

    try {
      await connection.connect();
      await connection.discoverServicesAndSetup();
      await _registerConnection(deviceId, connection);
    } catch (e) {
      debugPrint('[BleDeviceManager] Blad polaczenia z $deviceId: $e');
      rethrow;
    }
  }

  Future<void> _registerConnection(String deviceId, BleLockConnection connection) async {
    _connections[deviceId] = connection;
    await DatabaseService.instance.updateDeviceConnectionState(deviceId, true);

    await _connectionStateSubscriptions[deviceId]?.cancel();
    _connectionStateSubscriptions[deviceId] = connection.connectionStateStream.listen((state) async {
      if (state == BluetoothConnectionState.disconnected) {
        await _handleDeviceDisconnected(deviceId);
      }
    });

    await _lockStateSubscriptions[deviceId]?.cancel();
    _lockStateSubscriptions[deviceId] = connection.lockStateStream.listen((message) {
      logEvent(message, EventSource.bluetooth);
    });

    notifyListeners();
  }

  Future<void> logEvent(String message, EventSource source) async {
    final timestamp = DateTime.now();
    final event = DeviceEvent(
      id: timestamp.microsecondsSinceEpoch.toString(),
      message: message,
      timestamp: timestamp,
      source: source,
    );

    await DatabaseService.instance.insertEvent(event);
    _events.insert(0, event);
    _eventsOffset++;
    notifyListeners();
  }

  Future<void> setLockCommand(String deviceId, LockCommand command) async {
    final connection = getConnection(deviceId);
    if (connection == null) {
      throw Exception('Urzadzenie $deviceId nie jest polaczone.');
    }

    await connection.sendCommand(command);
  }

  Future<void> disconnectFromDevice(String deviceId) async {
    final connection = _connections[deviceId];
    if (connection != null) {
      await connection.disconnect();
      await _handleDeviceDisconnected(deviceId);
    }
  }

  Future<void> disconnectDevice(String deviceId) => disconnectFromDevice(deviceId);

  Future<void> _handleDeviceDisconnected(String deviceId) async {
    _connections.remove(deviceId);
    await _connectionStateSubscriptions.remove(deviceId)?.cancel();
    await _lockStateSubscriptions.remove(deviceId)?.cancel();
    await DatabaseService.instance.updateDeviceConnectionState(deviceId, false);
    notifyListeners();
  }

  Future<void> forgetDevice(String deviceId) async {
    await disconnectFromDevice(deviceId);
    await DatabaseService.instance.deleteDevice(deviceId);
    _savedDevices.removeWhere((device) => device.id == deviceId);
    notifyListeners();
  }

  BleLockConnection? getConnection(String deviceId) {
    return _connections[deviceId];
  }

  bool isConnected(String deviceId) {
    return _connections.containsKey(deviceId);
  }

  @override
  void dispose() {
    stopScan();
    _scanResultsController.close();
    _adapterStateSubscription?.cancel();
    for (final subscription in _connectionStateSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _lockStateSubscriptions.values) {
      subscription.cancel();
    }
    for (final connection in _connections.values) {
      connection.disconnect();
    }
    super.dispose();
  }
}
