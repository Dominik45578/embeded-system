class DeviceTelemetryPoint {
  final DateTime timestamp;
  final int lockState;
  final String message;
  final String source;

  DeviceTelemetryPoint({
    required this.timestamp,
    required this.lockState,
    required this.message,
    required this.source,
  });

  factory DeviceTelemetryPoint.fromJson(Map<String, dynamic> json) {
    return DeviceTelemetryPoint(
      timestamp: DateTime.parse(json['timestamp']),
      lockState: json['lockState'],
      message: json['message'],
      source: json['source'],
    );
  }

  String get normalizedSource => source.trim().toLowerCase();

  String get action {
    final normalizedMessage = message.trim().toUpperCase();

    if (normalizedMessage.contains('UNLOCK')) return 'unlock';
    if (normalizedMessage.contains('LOCK')) return 'lock';
    if (normalizedMessage.contains('PIN')) return 'pin';
    if (normalizedMessage.contains('BLOCK')) return 'block';

    return 'other';
  }
}
