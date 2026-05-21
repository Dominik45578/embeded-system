package com.example.backend.mqtt.controller;

import com.example.backend.mqtt.dto.request.LockLogRequest;
import com.example.backend.mqtt.service.device.DeviceLogProcessingService;
import com.kowallo.spring.mqttwebstarter.annotation.MqttController;
import com.kowallo.spring.mqttwebstarter.annotation.MqttMapping;
import com.kowallo.spring.mqttwebstarter.annotation.MqttPayload;
import com.kowallo.spring.mqttwebstarter.annotation.TopicVariable;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@MqttController
@RequiredArgsConstructor
@Slf4j
public class DeviceTelemetryMqttController {

    private final DeviceLogProcessingService logProcessingService;
    @MqttMapping("lockly/logs")
    public void handleDeviceLogs(
            @MqttPayload LockLogRequest request) {

        System.out.println("Received device logs request : " + request.toString());
        logProcessingService.processDeviceLog(request);
    }
}