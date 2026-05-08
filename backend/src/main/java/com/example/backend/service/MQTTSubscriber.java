package com.example.backend.service;

import com.example.backend.model.LockReceivePayload;
import com.influxdb.v3.client.InfluxDBClient;
import com.influxdb.v3.client.Point;
import lombok.RequiredArgsConstructor;
import org.eclipse.paho.client.mqttv3.IMqttMessageListener;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

@Component
@RequiredArgsConstructor
class MQTTSubscriber implements IMqttMessageListener {
    private final ObjectMapper objectMapper;
    private final InfluxDBClient influxDBClient;

    @Override
    public void messageArrived(String s, MqttMessage mqttMessage) {
        String rawPayload = new String(mqttMessage.getPayload());
        LockReceivePayload lockReceivePayload = objectMapper.readValue(rawPayload, LockReceivePayload.class);
        System.out.println("Received from MQTT: " + lockReceivePayload);

        Point point = Point.measurement("lock")
                .setTag("deviceId", lockReceivePayload.deviceId())
                .setField("lockState", lockReceivePayload.lockState().ordinal())
                .setTimestamp(lockReceivePayload.timestamp());
        try {
            influxDBClient.writePoint(point);
            System.out.println("Data has been saved to Influx");
        }
        catch (Exception e) {
            System.err.println("Failed to save data to Influx");
            e.printStackTrace();
        }
    }
}
