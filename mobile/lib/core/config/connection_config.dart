enum HttpProtocol { http, https }
enum ConnectionMode { local, server }

class ConnectionConfig {
  final ConnectionMode mode;
  final HttpProtocol protocol;
  final String host;
  final int identityPort;
  final int iotPort;
  final String serverIdentityUrl;
  final String serverIotUrl;

  const ConnectionConfig({
    this.mode = ConnectionMode.local,
    this.protocol = HttpProtocol.http,
    this.host = '100.99.243.73',
    this.identityPort = 12100,
    this.iotPort = 12200,
    this.serverIdentityUrl = '',
    this.serverIotUrl = '',
  });

  String get identityBaseUrl {
    return mode == ConnectionMode.local
        ? '${protocol.name}://$host:$identityPort/'
        : serverIdentityUrl;
  }

  String get iotBaseUrl {
    return mode == ConnectionMode.local
        ? '${protocol.name}://$host:$iotPort/api/v1'
        : serverIotUrl;
  }

  ConnectionConfig copyWith({
    ConnectionMode? mode,
    HttpProtocol? protocol,
    String? host,
    int? identityPort,
    int? iotPort,
    String? serverIdentityUrl,
    String? serverIotUrl,
  }) {
    return ConnectionConfig(
      mode: mode ?? this.mode,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      identityPort: identityPort ?? this.identityPort,
      iotPort: iotPort ?? this.iotPort,
      serverIdentityUrl: serverIdentityUrl ?? this.serverIdentityUrl,
      serverIotUrl: serverIotUrl ?? this.serverIotUrl,
    );
  }
}
