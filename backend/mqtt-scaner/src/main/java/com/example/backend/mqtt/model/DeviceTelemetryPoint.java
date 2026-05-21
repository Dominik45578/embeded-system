package com.example.backend.mqtt.model;

import java.time.Instant;

public record DeviceTelemetryPoint(
        Instant timestamp,
        int lockState,
        String message,
        String source
) {}