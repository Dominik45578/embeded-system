package com.example.backend.mqtt.service;

import com.example.backend.mqtt.dto.response.LockCommandResponse;

public interface MQTTPublisher {
    void publishCommand(String deviceId, LockCommandResponse commandResponse);
}