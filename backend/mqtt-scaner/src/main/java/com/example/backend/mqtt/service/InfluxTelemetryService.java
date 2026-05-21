package com.example.backend.mqtt.service;

import com.example.backend.mqtt.model.DeviceTelemetryPoint;

import java.util.List;

public interface InfluxTelemetryService {
    boolean hasRecentActivity(String deviceId, String range);
    List<DeviceTelemetryPoint> getTelemetry(String deviceId, String range);
}