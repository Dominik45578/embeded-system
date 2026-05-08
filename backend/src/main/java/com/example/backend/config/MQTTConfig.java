package com.example.backend.config;

import org.eclipse.paho.client.mqttv3.IMqttClient;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class MQTTConfig {

    @Bean
    public IMqttClient mqttClient(@Value("${BACKEND.MQTT.HOST}") String mqttHost) throws MqttException {
        return new MqttClient(mqttHost, MqttClient.generateClientId());
    }

}
