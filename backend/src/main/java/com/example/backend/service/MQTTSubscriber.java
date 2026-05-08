package com.example.backend.service;

import com.example.backend.model.LockReceivePayload;
import com.influxdb.client.InfluxDBClient;
import com.influxdb.client.WriteApiBlocking;
import com.influxdb.client.domain.WritePrecision;
import com.influxdb.client.write.Point;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.Validator;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.eclipse.paho.client.mqttv3.IMqttMessageListener;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.springframework.stereotype.Component;
import tools.jackson.databind.ObjectMapper;

import java.util.Set;

@Component
@RequiredArgsConstructor
@Slf4j
class MQTTSubscriber implements IMqttMessageListener {
    private final ObjectMapper objectMapper;
    private final InfluxDBClient influxDBClient;
    private final Validator validator;

    @Override
    public void messageArrived(String s, MqttMessage mqttMessage) {
        LockReceivePayload lockReceivePayload;

        String rawPayload = new String(mqttMessage.getPayload());
        log.debug("Received from MQTT: {}", rawPayload);

        try {
            lockReceivePayload = objectMapper.readValue(rawPayload, LockReceivePayload.class);
        }
        catch (Exception e) {
            log.warn("Failed to parse MQTT message: {}", e.getMessage());
            return;
        }

        Set<ConstraintViolation<LockReceivePayload>> violations = validator.validate(lockReceivePayload);
        if (!violations.isEmpty()) {
            StringBuilder stringBuilder = new StringBuilder();
            stringBuilder.append("MQTT message is invalid: [");

            for (ConstraintViolation<LockReceivePayload> violation : violations) {
                stringBuilder.append(violation.getPropertyPath()).append(": ").append(violation.getMessage()).append("; ");
            }

            stringBuilder.append("]");
            log.warn(stringBuilder.toString());
            return;
        }

        Point point = Point.measurement("lock")
                .addTag("deviceId", lockReceivePayload.deviceId())
                .addField("lockState", lockReceivePayload.lockState().ordinal())
                .time(lockReceivePayload.timestamp(), WritePrecision.MS);
        try {
            WriteApiBlocking writeApi = influxDBClient.getWriteApiBlocking();
            writeApi.writePoint(point);
            log.debug("Data has been saved to Influx");
        }
        catch (Exception e) {
            log.error("Failed to save data to Influx");
            e.printStackTrace();
        }
    }
}
