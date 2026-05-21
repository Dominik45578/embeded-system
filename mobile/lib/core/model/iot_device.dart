class IotDevice {
  final int? id;
  final String deviceId;
  final bool isBlocked;
  final String deviceName;
  // user jest niepotrzebny w aplikacji mobilnej

  IotDevice({
    this.id,
    required this.deviceId,
    required this.isBlocked,
    required this.deviceName,
  });

  factory IotDevice.fromJson(Map<String, dynamic> json) {
    return IotDevice(
      id: json['id'],
      deviceId: json['deviceId'],
      isBlocked: json['blocked'] ?? false,
      deviceName: json['deviceName'] ?? 'Zamek',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'blocked': isBlocked,
      'deviceName': deviceName,
    };
  }
}