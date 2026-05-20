enum EventSource { bluetooth, wifi }

class DeviceEvent {
  final String id;
  final String message;
  final DateTime timestamp;
  final EventSource source;

  DeviceEvent({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.source,
  });
}