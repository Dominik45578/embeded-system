package com.example.backend.mqtt.service;

import com.example.backend.mqtt.dto.response.LockCommandResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.eclipse.paho.client.mqttv3.IMqttClient;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
class PahoMQTTPublisher implements MQTTPublisher {

    private final IMqttClient mqttClient;
    private final ObjectMapper objectMapper;
    private static final String BASE_TOPIC = "lockly/";

    @Override
    public void publishCommand(String deviceId, LockCommandResponse commandResponse) {
        String topic = BASE_TOPIC + deviceId;
        try {
            byte[] payloadBytes = objectMapper.writeValueAsBytes(commandResponse);
            MqttMessage message = new MqttMessage(payloadBytes);
            message.setQos(1);
            
            mqttClient.publish(topic, message);
            log.debug("Published JSON command to {}: {}", topic, new String(payloadBytes));
        } catch (Exception e) {
            log.error("Failed to publish JSON command to device {}", deviceId, e);
        }
    }
}