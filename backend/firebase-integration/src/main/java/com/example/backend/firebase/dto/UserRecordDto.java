package com.example.backend.firebase.dto;

import lombok.Builder;
import lombok.Value;
import java.util.Map;

@Value
@Builder
public class UserRecordDto {
    String id;
    String email;
    String fullName;
    String avatarUrl;
    boolean active;
    boolean emailConfirmed;
    Map<String, Object> metadata;
}