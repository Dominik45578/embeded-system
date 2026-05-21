import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../api/api_client.dart';
import '../model/iot_device.dart';
import '../model/device_telemetry_point.dart';

class IotDeviceService {
  final ApiClient _apiClient = ApiClient.instance;

  Future<List<IotDevice>> getDevicesForCurrentUser() async {
    final Response response = await _apiClient.getIot('/devices');

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => IotDevice.fromJson(json)).toList();
    } else {
      throw Exception('Nie udało się załadować urządzeń: ${response.statusCode}');
    }
  }

  Future<IotDevice?> getDeviceDetails(String deviceId) async {
    try {
      final devices = await getDevicesForCurrentUser();
      return devices.firstWhere((d) => d.deviceId == deviceId);
    } catch (e) {
      if (e is StateError) {
        return null; // Nie znaleziono urządzenia w pobranej liście
      }
      rethrow;
    }
  }

  Future<IotDevice> addDevice({
    required String deviceId,
    String? deviceName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception("Brak zalogowanego użytkownika w Firebase Auth.");
    }

    final Response response = await _apiClient.postIot('/devices/add', {
      'deviceId': deviceId,
      'deviceName': deviceName ?? 'Nowy zamek',
      'uuid': user.uid, // Przesyłamy UUID konta użytkownika
    });

    if (response.statusCode == 201 || response.statusCode == 200) {
      return IotDevice.fromJson(response.data);
    } else {
      throw Exception('Nie udało się dodać urządzenia: ${response.statusCode} - ${response.data}');
    }
  }

  Future<void> sendCommand(String deviceId, String command) async {
    final Response response = await _apiClient.postIot('/devices/command', {
      'deviceId': deviceId,
      'command': command,
    });

    if (response.statusCode != 202 && response.statusCode != 200) {
      throw Exception('Błąd podczas wysyłania komendy: ${response.statusCode}');
    }
  }

  Future<void> toggleDeviceBlock(String deviceId, bool block) async {
    final Response response = await _apiClient.patchIot(
      '/devices/$deviceId/block?block=$block',
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Nie udało się zmienić stanu blokady: ${response.statusCode}');
    }
  }

  Future<bool> checkIsAlive(String deviceId) async {
    final Response response = await _apiClient.getIot('/devices/$deviceId/alive');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = response.data;
      return data['alive'] ?? false;
    } else {
      throw Exception('Błąd podczas sprawdzania statusu alive: ${response.statusCode}');
    }
  }

  Future<List<DeviceTelemetryPoint>> getDeviceTelemetry(
      String deviceId, {
        String range = '-24h',
      }) async {
    final Response response = await _apiClient.getIot(
      '/devices/$deviceId/telemetry?range=$range',
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;
      return data.map((json) => DeviceTelemetryPoint.fromJson(json)).toList();
    } else {
      throw Exception('Nie udało się załadować telemetrii: ${response.statusCode}');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<void> deleteDevice(String hardwareId) async {
    try {
      final Response response = await _apiClient.deleteIot('/devices/$hardwareId');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Serwer zwrócił nieoczekiwany kod statusu: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Błąd sieciowy podczas usuwania urządzenia: ${e.message}');
    }
  }
}