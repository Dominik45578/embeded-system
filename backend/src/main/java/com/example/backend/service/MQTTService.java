package com.example.backend.service;

import lombok.RequiredArgsConstructor;
import org.eclipse.paho.client.mqttv3.IMqttClient;
import org.eclipse.paho.client.mqttv3.IMqttMessageListener;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
class MQTTService {
    private final IMqttClient  mqttClient;
    private final IMqttMessageListener mqttListener;

    public MQTTService(@Value("${BACKEND.MQTT.TOPIC}") String mqttTopic, IMqttClient mqttClient, IMqttMessageListener mqttListener) throws MqttException {

        MqttConnectOptions options = new MqttConnectOptions();
        options.setAutomaticReconnect(true);
        options.setCleanSession(true);
        options.setConnectionTimeout(10);

        mqttClient.connect(options);
        mqttClient.subscribe(mqttTopic, mqttListener);

        this.mqttClient = mqttClient;
        this.mqttListener = mqttListener;
    }

    public boolean sendPayload(String payload) {
        return false; // Placeholder
    }
}
