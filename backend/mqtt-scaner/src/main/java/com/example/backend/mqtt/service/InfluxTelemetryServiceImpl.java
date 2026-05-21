package com.example.backend.mqtt.service;

import com.example.backend.mqtt.config.influx.InfluxProperties;
import com.example.backend.mqtt.model.DeviceTelemetryPoint;
import com.influxdb.client.InfluxDBClient;
import com.influxdb.query.FluxRecord;
import com.influxdb.query.FluxTable;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class InfluxTelemetryServiceImpl implements InfluxTelemetryService {

    private final InfluxDBClient influxDBClient;
    private final InfluxProperties influxProperties;

    @Override
    public boolean hasRecentActivity(String deviceId, String range) {
        String flux = String.format(
                "from(bucket: \"%s\") " +
                "|> range(start: %s) " +
                "|> filter(fn: (r) => r[\"_measurement\"] == \"lock_logs\") " +
                "|> filter(fn: (r) => r[\"deviceId\"] == \"%s\") " +
                "|> limit(n: 1)",
                influxProperties.getBucket(), range, deviceId
        );

        List<FluxTable> tables = influxDBClient.getQueryApi().query(flux, influxProperties.getOrg());
        return !tables.isEmpty() && !tables.get(0).getRecords().isEmpty();
    }

    @Override
    public List<DeviceTelemetryPoint> getTelemetry(String deviceId, String range) {
        // Użycie pivot() pozwala na zgrupowanie pól lockState, message i source z jednego punktu czasowego w jeden rekord
        String flux = String.format(
                "from(bucket: \"%s\") " +
                "|> range(start: %s) " +
                "|> filter(fn: (r) => r[\"_measurement\"] == \"lock_logs\") " +
                "|> filter(fn: (r) => r[\"deviceId\"] == \"%s\") " +
                "|> pivot(rowKey:[\"_time\"], columnKey: [\"_field\"], valueColumn: \"_value\") " +
                "|> sort(columns: [\"_time\"], desc: true)",
                influxProperties.getBucket(), range, deviceId
        );

        List<FluxTable> tables = influxDBClient.getQueryApi().query(flux, influxProperties.getOrg());
        List<DeviceTelemetryPoint> telemetryPoints = new ArrayList<>();

        for (FluxTable table : tables) {
            for (FluxRecord record : table.getRecords()) {
                Instant timestamp = record.getTime();
                
                Long lockStateLong = (Long) record.getValueByKey("lockState");
                int lockState = lockStateLong != null ? lockStateLong.intValue() : 0;
                
                String message = (String) record.getValueByKey("message");
                String source = (String) record.getValueByKey("source");

                telemetryPoints.add(new DeviceTelemetryPoint(timestamp, lockState, message, source));
            }
        }
        return telemetryPoints;
    }
}