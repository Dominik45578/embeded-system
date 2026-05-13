import 'package:flutter/foundation.dart';

@immutable
class UserRecordDto {
  final String id;
  final String email;
  final String fullName;
  final String avatarUrl;
  final bool active;
  final bool emailConfirmed;
  final Map<String, dynamic> metadata;

  const UserRecordDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.avatarUrl,
    required this.active,
    required this.emailConfirmed,
    required this.metadata,
  });

  factory UserRecordDto.fromJson(Map<String, dynamic> json) {
    return UserRecordDto(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      active: json['active'] as bool? ?? false,
      emailConfirmed: json['emailConfirmed'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }
}