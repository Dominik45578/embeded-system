import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../model/auth_token_dto.dart';
import '../model/user_record_dto.dart';


class IdentityService extends ChangeNotifier {
  IdentityService._internal();
  static final IdentityService instance = IdentityService._internal();

  final ApiClient _apiClient = ApiClient.instance;

  UserRecordDto? _currentUserRecord;
  AuthTokenDto? _currentAuthToken;
  bool _isLoading = false;
  String? _errorMessage;

  UserRecordDto? get currentUserRecord => _currentUserRecord;
  AuthTokenDto? get currentAuthToken => _currentAuthToken;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<UserRecordDto?> fetchIdentity(String uuid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Response response = await _apiClient.getIdentity('user/$uuid');
      
      if (response.statusCode == 200) {
        // Dio automatycznie dekoduje JSON, więc używamy response.data
        _currentUserRecord = UserRecordDto.fromJson(response.data);
        return _currentUserRecord;
      } else {
        _errorMessage = 'Błąd pobierania tożsamości: ${response.statusCode} - ${response.statusMessage}';
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) {
        print(_errorMessage);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<AuthTokenDto?> verifyToken(String idToken) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Response response = await _apiClient.postIdentity('user/auth', {'idToken': idToken});
      
      if (response.statusCode == 200) {
        _currentAuthToken = AuthTokenDto.fromJson(response.data);
        return _currentAuthToken;
      } else {
        _errorMessage = 'Błąd weryfikacji tokenu: ${response.statusCode} - ${response.statusMessage}';
      }
    } catch (e) {
      _errorMessage = e.toString();
      if (kDebugMode) {
        print(_errorMessage);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }
}