import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/connection_config.dart';

class ConnectionConfigService extends ChangeNotifier {
  ConnectionConfigService._internal();
  static final ConnectionConfigService instance = ConnectionConfigService._internal();

  static const String _keyProtocol = 'net_protocol';
  static const String _keyHost = 'net_host';
  static const String _keyIdentityPort = 'net_identity_port';
  static const String _keyIotPort = 'net_iot_port';

  ConnectionConfig _config = const ConnectionConfig(
    protocol: HttpProtocol.http,
    host: 'localhost',
    iotPort: 12200,
    identityPort: 12100,
  );

  ConnectionConfig get config => _config;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final protocolRaw = prefs.getString(_keyProtocol);
    final host = prefs.getString(_keyHost);
    final identityPort = prefs.getInt(_keyIdentityPort);
    final iotPort = prefs.getInt(_keyIotPort);

    if (protocolRaw != null && host != null && identityPort != null && iotPort != null) {
      final protocol = HttpProtocol.values.firstWhere(
            (e) => e.name == protocolRaw,
        orElse: () => HttpProtocol.http,
      );

      _config = ConnectionConfig(
        protocol: protocol,
        host: host,
        identityPort: identityPort,
        iotPort: iotPort,
      );
      notifyListeners();
    }
  }

  Future<void> updateConfig(ConnectionConfig newConfig) async {
    if (_config == newConfig) return;
    _config = newConfig;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProtocol, newConfig.protocol.name);
    await prefs.setString(_keyHost, newConfig.host);
    await prefs.setInt(_keyIdentityPort, newConfig.identityPort);
    await prefs.setInt(_keyIotPort, newConfig.iotPort);
  }
}