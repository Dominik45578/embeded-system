package com.example.backend.service;

import com.example.backend.model.LockReceivePayload;
import lombok.RequiredArgsConstructor;
import org.eclipse.paho.client.mqttv3.IMqttMessageListener;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

@Component
@RequiredArgsConstructor
class MQTTSubscriber implements IMqttMessageListener {
    private final ObjectMapper objectMapper;

    @Override
    public void messageArrived(String s, MqttMessage mqttMessage) throws Exception {
        String rawPayload = new String(mqttMessage.getPayload());
        LockReceivePayload lockReceivePayload = objectMapper.readValue(rawPayload, LockReceivePayload.class);
        System.out.println(lockReceivePayload); // Placeholder, saving to Influx will be here later
    }
}
