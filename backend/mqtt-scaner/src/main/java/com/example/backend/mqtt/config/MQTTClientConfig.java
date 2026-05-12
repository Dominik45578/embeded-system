package com.example.backend.mqtt.config;

import lombok.AllArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.eclipse.paho.client.mqttv3.*;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.event.EventListener;


@Slf4j
@Configuration
@EnableConfigurationProperties(MqttProperties.class)
@AllArgsConstructor
public class MQTTClientConfig {
    private final IMqttClient mqttClient;
    private final IMqttMessageListener mqttListener;
    private final MqttProperties mqttProperties;

    @EventListener(ApplicationReadyEvent.class)
    public void initMqttConnection() {
        try {
            MqttConnectOptions options = new MqttConnectOptions();
            options.setAutomaticReconnect(true);
            options.setCleanSession(true);
            options.setConnectionTimeout(10);

            log.debug("Attempting to connect to MQTT broker...");
            mqttClient.connect(options);
            mqttClient.subscribe(mqttProperties.getTopic(), mqttListener);

            log.info("Successfully connected and subscribed to MQTT topic: {}", mqttProperties.getTopic());
        } catch (MqttException e) {
            log.error("Failed to connect to MQTT broker on application startup", e);
        }
    }
}
