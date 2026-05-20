import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../model/device_event.dart';
import '../../model/lock_command.dart';
import '../database_service.dart';
import 'ble_lock_connection.dart';

class BleDeviceManager extends ChangeNotifier {
  static final BleDeviceManager _instance = BleDeviceManager._internal();
  factory BleDeviceManager() => _instance;
  BleDeviceManager._internal();

  static const String _storageKey = 'bonded_ble_devices';
  final List<DeviceEvent> _events = [];
  List<DeviceEvent> get events => List.unmodifiable(_events);

  bool _hasMoreEvents = true;
  bool get hasMoreEvents => _hasMoreEvents;

  final DatabaseService _dbService = DatabaseService.instance;
  final Map<String, StreamSubscription> _streamSubscriptions = {};

  // Słownik aktywnych obiektów sesji sesji połączeń
  final Map<String, BleLockConnection> _activeConnections = {};
  
  // Lista identyfikatorów (MAC adresów) trwale zapisanych w pamięci urządzenia
  List<String> _savedDeviceIds = [];

  List<String> get savedDeviceIds => _savedDeviceIds;

  /// Inicjalizacja managera – wywołaj ją przy starcie aplikacji (np. w main.dart)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _savedDeviceIds = prefs.getStringList(_storageKey) ?? [];

    await fetchNextEventsPage(isRefresh: true);
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

    _streamSubscriptions[deviceId] = connection.lockStateStream.listen((rawMessage) {
      logEvent(rawMessage, EventSource.bluetooth);
    });

    notifyListeners();
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

  Future<void> fetchNextEventsPage({bool isRefresh = false}) async {
    if (isRefresh) {
      _events.clear();
      _hasMoreEvents = true;
    }

    if (!_hasMoreEvents) return;

    final int currentOffset = _events.length;
    final List<DeviceEvent> newPage = await _dbService.getPagedEvents(20, currentOffset);

    if (newPage.length < 20) {
      _hasMoreEvents = false; // Baza nie ma więcej rekordów
    }

    _events.addAll(newPage);
    notifyListeners();
  }

  /// Zapisuje zdarzenie w bazie i aktualizuje reaktywny bufor w pamięci operacyjnej
  Future<void> logEvent(String message, EventSource source) async {
    final newEvent = DeviceEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      message: message,
      timestamp: DateTime.now(),
      source: source,
    );

    // 1. Zapis trwały w bazie danych
    await _dbService.insertEvent(newEvent);

    // 2. Aktualizacja pamięci podręcznej UI (wstrzyknięcie na początek listy)
    _events.insert(0, newEvent);
    notifyListeners();
  }
}