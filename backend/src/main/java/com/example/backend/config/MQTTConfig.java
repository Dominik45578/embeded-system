package com.example.backend.config;

import org.eclipse.paho.client.mqttv3.IMqttClient;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(MqttProperties.class)
class MQTTConfig {

    @Bean
    public IMqttClient mqttClient(MqttProperties mqttProperties) throws MqttException {
        return new MqttClient(mqttProperties.getHost(), MqttClient.generateClientId());
    }

}
