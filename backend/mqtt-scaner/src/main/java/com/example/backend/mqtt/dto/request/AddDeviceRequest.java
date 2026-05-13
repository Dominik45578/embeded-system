package com.example.backend.mqtt.dto.request;

import jakarta.validation.constraints.NotBlank;

public record AddDeviceRequest(
        @NotBlank(message = "UUID użytkownika jest wymagane.")
        String uuid,

        @NotBlank(message = "Identyfikator urządzenia (deviceId) jest wymagany.")
        String deviceId,

        String deviceName
) {}