package com.example.backend.mqtt.service;

import com.example.backend.mqtt.dto.request.LockLogRequest;
import com.example.backend.mqtt.repository.DeviceRepository;
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
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.Set;

@Component
@RequiredArgsConstructor
@Slf4j
class MQTTSubscriber implements IMqttMessageListener {

    private final ObjectMapper objectMapper;
    private final InfluxDBClient influxDBClient;
    private final Validator validator;
    private final DeviceRepository deviceRepository;
    private final NotificationPublisher notificationPublisher;

    @Override
    public void messageArrived(String topic, MqttMessage mqttMessage) {
        String rawPayload = new String(mqttMessage.getPayload());
        log.debug("Received raw JSON from MQTT topic {}: {}", topic, rawPayload);

        LockLogRequest request;
        try {
            request = objectMapper.readValue(rawPayload, LockLogRequest.class);
        } catch (Exception e) {
            log.warn("Failed to parse MQTT JSON payload: {}", e.getMessage());
            return;
        }

        if (!isValid(request)) return;

        deviceRepository.findByDeviceId(request.deviceId()).ifPresentOrElse(
                device -> {
                    if (device.isBlocked()) {
                        log.warn("Device {} is blocked. Ignoring log request.", device.getDeviceId());
                        return;
                    }
                    notificationPublisher.notifyStateChange(device, request.lockState());
                    saveToInflux(request);
                },
                () -> log.warn("Device {} not found in DB. Request rejected.", request.deviceId())
        );
    }

    private boolean isValid(LockLogRequest payload) {
        Set<ConstraintViolation<LockLogRequest>> violations = validator.validate(payload);
        if (!violations.isEmpty()) {
            StringBuilder stringBuilder = new StringBuilder("JSON Payload is invalid: [");
            for (ConstraintViolation<LockLogRequest> violation : violations) {
                stringBuilder.append(violation.getPropertyPath()).append(": ")
                        .append(violation.getMessage()).append("; ");
            }
            stringBuilder.append("]");
            log.warn(stringBuilder.toString());
            return false;
        }
        return true;
    }

    private void saveToInflux(LockLogRequest request) {
        Point point = Point.measurement("lock_logs")
                .addTag("deviceId", request.deviceId())
                .addField("lockState", request.lockState().ordinal())
                .addField("message", request.message())
                .time(request.timestamp(), WritePrecision.MS);
        try {
            WriteApiBlocking writeApi = influxDBClient.getWriteApiBlocking();
            writeApi.writePoint(point);
            log.debug("Device log data saved to InfluxDB");
        } catch (Exception e) {
            log.error("Failed to save device log data to InfluxDB", e);
        }
    }
}