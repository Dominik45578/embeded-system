enum HttpProtocol { http, https }

class ConnectionConfig {
  final HttpProtocol protocol;
  final String host;
  final int identityPort;
  final int iotPort;

  const ConnectionConfig({
    required this.protocol,
    required this.host,
    required this.identityPort,
    required this.iotPort,
  });

  String get identityBaseUrl => '${protocol.name}://$host:$identityPort/user/';
  String get iotBaseUrl => '${protocol.name}://$host:$iotPort/api/v1';

  ConnectionConfig copyWith({
    HttpProtocol? protocol,
    String? host,
    int? identityPort,
    int? iotPort,
  }) {
    return ConnectionConfig(
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      identityPort: identityPort ?? this.identityPort,
      iotPort: iotPort ?? this.iotPort,
    );
  }
}