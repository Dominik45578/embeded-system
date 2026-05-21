package com.example.backend.mqtt.dto.request;

import jakarta.validation.constraints.NotBlank;

public record FcmTokenRequest(
        @NotBlank
        String fcmToken
) {}