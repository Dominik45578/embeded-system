package com.example.backend.firebase.dto;

import lombok.Builder;
import lombok.Value;
import java.util.List;
import java.util.Map;

@Value
@Builder
public class AuthTokenDto {
    String uid;
    String email;
    String name;
    String issuer;
    String photoUrl;
    List<String> roles;
    Map<String, Object> allClaims;
}