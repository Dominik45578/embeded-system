import 'package:flutter/foundation.dart';

@immutable
class AuthTokenDto {
  final String uid;
  final String email;
  final String name;
  final String issuer;
  final String photoUrl;
  final List<String>? roles;
  final Map<String, dynamic>? allClaims;

  const AuthTokenDto({
    required this.uid,
    required this.email,
    required this.name,
    required this.issuer,
    required this.photoUrl,
     this.roles,
     this.allClaims,
  });

  factory AuthTokenDto.fromJson(Map<String, dynamic> json) {
    return AuthTokenDto(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      issuer: json['issuer'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      roles: (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      allClaims: json['allClaims'] as Map<String, dynamic>? ?? const {},
    );
  }
}