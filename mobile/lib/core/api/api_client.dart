import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/connection_config_service.dart';

class ApiClient {
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  final ConnectionConfigService _configService = ConnectionConfigService.instance;

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

  Future<http.Response> getIdentity(String endpoint) async {
    final url = Uri.parse('$identityApi$endpoint');
    final headers = await _getHeaders();
    return await http.get(url, headers: headers);
  }

  Future<http.Response> postIdentity(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$identityApi$endpoint');
    final headers = await _getHeaders();
    return await http.post(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> getIot(String endpoint) async {
    final url = Uri.parse('$iotApi$endpoint');
    final headers = await _getHeaders();
    return await http.get(url, headers: headers);
  }

  Future<http.Response> postIot(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$iotApi$endpoint');
    final headers = await _getHeaders();
    return await http.post(url, headers: headers, body: jsonEncode(body));
  }

  Future<http.Response> patchIot(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$iotApi$endpoint');
    final headers = await _getHeaders();
    return await http.patch(url, headers: headers, body: body != null ? jsonEncode(body) : null);
  }
}