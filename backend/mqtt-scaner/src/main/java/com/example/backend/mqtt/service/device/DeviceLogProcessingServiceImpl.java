package com.example.backend.mqtt.service.device;

import com.example.backend.mqtt.DevicePingManager;
import com.example.backend.mqtt.config.influx.InfluxProperties;
import com.example.backend.mqtt.dto.request.LockLogRequest;
import com.example.backend.mqtt.entity.User;
import com.example.backend.mqtt.repository.DeviceRepository;
import com.example.backend.mqtt.repository.UserRepository;
import com.example.backend.mqtt.service.notification.NotificationPublisher;
import com.influxdb.client.InfluxDBClient;
import com.influxdb.client.WriteApiBlocking;
import com.influxdb.client.domain.WritePrecision;
import com.influxdb.client.write.Point;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class DeviceLogProcessingServiceImpl implements DeviceLogProcessingService {

    private final DeviceRepository deviceRepository;
    private final UserRepository userRepository;
    private final NotificationPublisher notificationPublisher;
    private final InfluxDBClient influxDBClient;
    private final InfluxProperties influxProperties;
    private final DevicePingManager devicePingManager;

    @Override
    public void processDeviceLog(LockLogRequest request) {
        log.info("Device log processing started");

        devicePingManager.completePing(request.deviceId(), request.lockState());

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

    private void saveToInflux(LockLogRequest request) {
        log.info("Saving log request to InfluxDB");
        Point point = Point.measurement("lock_logs")
                .addTag("deviceId", request.deviceId())
                .addField("lockState", request.lockState().ordinal())
                .addField("message", request.message())
                .addField("source", request.source())
                .time(request.timestamp(), WritePrecision.MS);
        try {
            WriteApiBlocking writeApi = influxDBClient.getWriteApiBlocking();
            writeApi.writePoint(influxProperties.getBucket(), influxProperties.getOrg(), point);
            log.debug("Device log data saved to InfluxDB");
        } catch (Exception e) {
            log.error("Failed to save device log data to InfluxDB", e);
        }
    }
}