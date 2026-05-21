import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class UserBootstrapService extends ChangeNotifier {
  UserBootstrapService._internal();
  static final UserBootstrapService instance = UserBootstrapService._internal();

  final ApiClient _apiClient = ApiClient.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<String>? _fcmTokenSubscription;
  Future<void>? _runningBootstrap;
  Timer? _backgroundRetryTimer; // Referencja do okresowego timera w tle

  String? _lastUploadedFcmToken;
  String? _readyUserUid;
  bool _isReady = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isReady => _isReady;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void reset() {
    _cancelBackgroundRetry();
    if (!_isReady &&
        !_isLoading &&
        _errorMessage == null &&
        _readyUserUid == null &&
        _lastUploadedFcmToken == null) {
      return;
    }

    _isReady = false;
    _isLoading = false;
    _errorMessage = null;
    _readyUserUid = null;
    _lastUploadedFcmToken = null;
    notifyListeners();
  }

  Future<void> ensureCurrentUserReady() {
    final user = _auth.currentUser;
    if (user != null && _isReady && _readyUserUid == user.uid) {
      return Future.value();
    }

    _runningBootstrap ??= _bootstrap().whenComplete(() {
      _runningBootstrap = null;
    });
    return _runningBootstrap!;
  }

  Future<void> _bootstrap() async {
    final user = _auth.currentUser;
    if (user == null) {
      _clearBootstrapState();
      return;
    }

    _isLoading = true;
    _isReady = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final idToken = await user.getIdToken(true);
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Brak tokena Firebase dla zalogowanego użytkownika.');
      }

      await _syncUser(idToken);
      await _registerFcmToken();
      _listenForFcmTokenRefresh();

      _isReady = true;
      _readyUserUid = user.uid;
      _cancelBackgroundRetry(); // Sukces, wyłączamy pętlę ponowień
    } catch (e) {
      _isReady = false;
      _readyUserUid = null;
      _errorMessage = e.toString();

      if (kDebugMode) {
        debugPrint('User bootstrap failed: $_errorMessage. Uruchamianie synchronizacji w tle...');
      }

      _scheduleBackgroundRetry(); // Błąd, uruchamiamy ciche sprawdzanie w tle
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Inicjalizuje cichą pętlę ponowień (wywoływaną np. co 45 sekund)
  void _scheduleBackgroundRetry() {
    if (_backgroundRetryTimer != null && _backgroundRetryTimer!.isActive) {
      return;
    }

    _backgroundRetryTimer = Timer.periodic(const Duration(seconds: 45), (timer) async {
      final user = _auth.currentUser;
      if (user == null) {
        _cancelBackgroundRetry();
        return;
      }

      try {
        if (kDebugMode) {
          debugPrint('[UserBootstrapService] Cicha próba synchronizacji danych w tle...');
        }

        final idToken = await user.getIdToken(true);
        if (idToken != null && idToken.isNotEmpty) {
          await _syncUser(idToken);
          await _registerFcmToken();
          _listenForFcmTokenRefresh();

          // Jeśli wszystko przeszło bez wyjątków, aktualizujemy stan i sprzątamy timer
          _isReady = true;
          _readyUserUid = user.uid;
          _errorMessage = null;
          _cancelBackgroundRetry();
          notifyListeners();

          if (kDebugMode) {
            debugPrint('[UserBootstrapService] Synchronizacja w tle zakończona pełnym sukcesem.');
          }
        }
      } catch (e) {
        // Logujemy błąd w konsoli debugowania, ale nie dotykamy UI, aby nie rozpraszać użytkownika
        if (kDebugMode) {
          debugPrint('[UserBootstrapService] Kolejna próba w tle nie powiodła się: $e');
        }
      }
    });
  }

  void _cancelBackgroundRetry() {
    _backgroundRetryTimer?.cancel();
    _backgroundRetryTimer = null;
  }

  Future<void> _syncUser(String idToken) async {
    final response = await _apiClient.postIot('/users/sync', {'token': idToken});
    _throwIfNotSuccess(
      response,
      'Nie udało się zsynchronizować profilu użytkownika',
    );
  }

  Future<void> _registerFcmToken() async {
    await _messaging.requestPermission();
    final fcmToken = await _messaging.getToken();
    if (fcmToken == null || fcmToken.isEmpty) {
      throw StateError('Nie udało się pobrać tokena FCM.');
    }

    await _uploadFcmToken(fcmToken);
  }

  void _listenForFcmTokenRefresh() {
    _fcmTokenSubscription ??= _messaging.onTokenRefresh.listen((fcmToken) async {
      if (_auth.currentUser == null || fcmToken.isEmpty) {
        return;
      }

      try {
        await _uploadFcmToken(fcmToken);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('FCM token refresh upload failed: $e');
        }
      }
    });
  }

  Future<void> _uploadFcmToken(String fcmToken) async {
    if (_lastUploadedFcmToken == fcmToken) {
      return;
    }

    final response = await _apiClient.putIot('/users/fcm-token', {
      'fcmToken': fcmToken,
    });
    _throwIfNotSuccess(response, 'Nie udało się wysłać tokena FCM');
    _lastUploadedFcmToken = fcmToken;
  }

  void _throwIfNotSuccess(Response response, String message) {
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception('$message: $statusCode ${response.data ?? ''}');
    }
  }

  void _clearBootstrapState() {
    _isReady = false;
    _readyUserUid = null;
    _lastUploadedFcmToken = null;
    _isLoading = false;
    _errorMessage = null;
    _cancelBackgroundRetry();
    notifyListeners();
  }

  @override
  void dispose() {
    _fcmTokenSubscription?.cancel();
    _backgroundRetryTimer?.cancel();
    super.dispose();
  }
}