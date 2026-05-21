package com.example.backend.mqtt.dto.response;

import java.time.Instant;

public record DeviceResponse(
        Long id,
        String deviceId,
        boolean blocked,
        String deviceName
) {}