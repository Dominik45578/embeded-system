package com.example.backend.mqtt.service.device;

import com.example.backend.mqtt.dto.response.LockCommandResponse;
import com.kowallo.spring.mqttwebstarter.annotation.MqttPublisher;
import com.kowallo.spring.mqttwebstarter.annotation.MqttPublisherTopic;
import com.kowallo.spring.mqttwebstarter.annotation.TopicVariable;

@MqttPublisher("device/")
public interface DeviceCommandMqttPublisher {

    /**
     * Publishes a control command to a specific device.
     * The response payload object is automatically serialized to JSON.
     *
     * @param deviceId  Dynamic target device identifier
     * @param payload   Command packet configuration
     */
    @MqttPublisherTopic("{deviceId}")
    void sendCommand(
            @TopicVariable("deviceId") String deviceId,
            LockCommandResponse payload
    );
}