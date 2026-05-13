import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../model/device.dart';


class IotDeviceService extends ChangeNotifier {
  IotDeviceService._internal();
  static final IotDeviceService instance = IotDeviceService._internal();

  final ApiClient _apiClient = ApiClient.instance;

  List<Device> _devices = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMyDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.getIot('/devices');
      if (response.statusCode == 200) {
        final List<dynamic> decodedData = jsonDecode(response.body);
        _devices = decodedData.map((json) => Device.fromJson(json)).toList();
      } else {
        _errorMessage = 'Błąd pobierania urządzeń: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendCommand(String deviceId, String command) async {
    try {
      final response = await _apiClient.postIot('/devices/command', {
        'deviceId': deviceId,
        'command': command,
      });
      return response.statusCode == 202;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleDeviceBlock(String deviceId, bool block) async {
    try {
      final response = await _apiClient.patchIot('/devices/$deviceId/block?block=$block');
      if (response.statusCode == 204) {
        final int index = _devices.indexWhere((device) => device.id == deviceId);
        if (index != -1) {
          _devices[index] = _devices[index].copyWith(isBlocked: block);
          notifyListeners();
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}