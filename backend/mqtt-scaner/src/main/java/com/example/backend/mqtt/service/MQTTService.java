package com.example.backend.mqtt.service;

import com.example.backend.mqtt.config.MqttProperties;
import org.eclipse.paho.client.mqttv3.IMqttClient;
import org.eclipse.paho.client.mqttv3.IMqttMessageListener;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.springframework.stereotype.Service;

@Service
class MQTTService {
    private final IMqttClient  mqttClient;
    private final IMqttMessageListener mqttListener;

    public MQTTService(MqttProperties mqttProperties, IMqttClient mqttClient, IMqttMessageListener mqttListener) throws MqttException {

        MqttConnectOptions options = new MqttConnectOptions();
        options.setAutomaticReconnect(true);
        options.setCleanSession(true);
        options.setConnectionTimeout(10);

        mqttClient.connect(options);
        mqttClient.subscribe(mqttProperties.getTopic(), mqttListener);

        this.mqttClient = mqttClient;
        this.mqttListener = mqttListener;
    }

    public boolean sendPayload(String payload) {
        return false; // Placeholder
    }
}
