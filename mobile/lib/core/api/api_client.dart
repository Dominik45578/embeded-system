import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/connection_config_service.dart';

class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        // Dio domyślnie podąża za przekierowaniami, co rozwiąże problem z Cloudflare Tunnel
        followRedirects: true,
        maxRedirects: 5,
        // Zapobiega rzucaniu wyjątków DioException dla statusów innych niż 2xx, 
        // aby logika obsługi błędów w serwisach pozostała niezmieniona
        validateStatus: (status) => true,
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;
  final ConnectionConfigService _configService =
      ConnectionConfigService.instance;

  String get identityApi => _configService.config.identityBaseUrl;
  String get iotApi => _configService.config.iotBaseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final User? user = FirebaseAuth.instance.currentUser;
    final String? token = await user?.getIdToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- IDENTITY API ---

  Future<Response> getIdentity(String endpoint) async {
    final url = '$identityApi$endpoint';
    final headers = await _getHeaders();
    return await _dio.get(url, options: Options(headers: headers));
  }

  Future<Response> postIdentity(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = '$identityApi$endpoint';
    final headers = await _getHeaders();
    return await _dio.post(url, data: body, options: Options(headers: headers));
  }

  // --- IOT API ---

  Future<Response> getIot(String endpoint) async {
    final url = '$iotApi$endpoint';
    final headers = await _getHeaders();
    return await _dio.get(url, options: Options(headers: headers));
  }

  Future<Response> postIot(String endpoint, Map<String, dynamic> body) async {
    final url = '$iotApi$endpoint';
    final headers = await _getHeaders();
    return await _dio.post(url, data: body, options: Options(headers: headers));
  }

  Future<Response> putIot(String endpoint, Map<String, dynamic> body) async {
    final url = '$iotApi$endpoint';
    final headers = await _getHeaders();
    return await _dio.put(url, data: body, options: Options(headers: headers));
  }

  Future<Response> patchIot(String endpoint, {Map<String, dynamic>? body}) async {
    final url = '$iotApi$endpoint';
    final headers = await _getHeaders();
    return await _dio.patch(url, data: body, options: Options(headers: headers));
  }
  Future<Response> deleteIot(String endpoint, {Map<String, dynamic>? body}) async {
    final url = '$iotApi$endpoint';
    final headers = await _getHeaders();
    return await _dio.delete(url, data: body, options: Options(headers: headers));
  }
}
