import 'package:flutter/foundation.dart';

@immutable
class Device {
  final String id;  
  final String hardwareId;
  final String name;
  final bool isBlocked;

  const Device({
    required this.id,
    required this.hardwareId,
    required this.name,
    required this.isBlocked,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String? ?? '',
      hardwareId: json['hardwareId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isBlocked: json['isBlocked'] as bool? ?? false,
    );
  }

  Device copyWith({
    String? id,
    String? hardwareId,
    String? name,
    bool? isBlocked,
  }) {
    return Device(
      id: id ?? this.id,
      hardwareId: hardwareId ?? this.hardwareId,
      name: name ?? this.name,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}