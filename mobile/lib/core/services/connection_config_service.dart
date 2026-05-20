import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/connection_config.dart';

class ConnectionConfigService extends ChangeNotifier {
  ConnectionConfigService._internal();
  static final ConnectionConfigService instance = ConnectionConfigService._internal();

  static const String _keyMode = 'net_mode';
  static const String _keyProtocol = 'net_protocol';
  static const String _keyHost = 'net_host';
  static const String _keyIdentityPort = 'net_identity_port';
  static const String _keyIotPort = 'net_iot_port';
  static const String _keyServerIdentityUrl = 'net_server_identity_url';
  static const String _keyServerIotUrl = 'net_server_iot_url';

  ConnectionConfig _config = const ConnectionConfig();

  ConnectionConfig get config => _config;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final modeRaw = prefs.getString(_keyMode);
    final protocolRaw = prefs.getString(_keyProtocol);
    final host = prefs.getString(_keyHost);
    final identityPort = prefs.getInt(_keyIdentityPort);
    final iotPort = prefs.getInt(_keyIotPort);
    final serverIdentityUrl = prefs.getString(_keyServerIdentityUrl);
    final serverIotUrl = prefs.getString(_keyServerIotUrl);

    if (modeRaw != null) {
      final mode = ConnectionMode.values.firstWhere(
            (e) => e.name == modeRaw,
        orElse: () => ConnectionMode.local,
      );

      final protocol = HttpProtocol.values.firstWhere(
            (e) => e.name == protocolRaw,
        orElse: () => HttpProtocol.http,
      );

      _config = ConnectionConfig(
        mode: mode,
        protocol: protocol,
        host: host ?? 'localhost',
        identityPort: identityPort ?? 12100,
        iotPort: iotPort ?? 12200,
        serverIdentityUrl: serverIdentityUrl ?? '',
        serverIotUrl: serverIotUrl ?? '',
      );
      notifyListeners();
    }
  }

  Future<void> updateConfig(ConnectionConfig newConfig) async {
    if (_config == newConfig) return;
    _config = newConfig;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, newConfig.mode.name);
    await prefs.setString(_keyProtocol, newConfig.protocol.name);
    await prefs.setString(_keyHost, newConfig.host);
    await prefs.setInt(_keyIdentityPort, newConfig.identityPort);
    await prefs.setInt(_keyIotPort, newConfig.iotPort);
    await prefs.setString(_keyServerIdentityUrl, newConfig.serverIdentityUrl);
    await prefs.setString(_keyServerIotUrl, newConfig.serverIotUrl);
  }
}