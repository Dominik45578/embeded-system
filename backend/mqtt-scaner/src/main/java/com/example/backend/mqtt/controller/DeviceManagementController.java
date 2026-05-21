package com.example.backend.mqtt.controller;

import com.example.backend.mqtt.dto.request.AddDeviceRequest;
import com.example.backend.mqtt.dto.request.DeviceCommandRequest;
import com.example.backend.mqtt.dto.response.DeviceResponse;
import com.example.backend.mqtt.entity.Device;
import com.example.backend.mqtt.model.DeviceTelemetryPoint;
import com.example.backend.mqtt.service.device.DeviceManagementService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@Slf4j
@RestController
@RequestMapping("/api/v1/devices")
@RequiredArgsConstructor
public class DeviceManagementController {

    private final DeviceManagementService deviceManagementService;

    @GetMapping
    public ResponseEntity<List<DeviceResponse>> getMyDevices(Authentication authentication) {
        log.info("Getting devices for user: {}", authentication.getName());
        return ResponseEntity.ok(deviceManagementService.getUserDevices(authentication.getName()));
    }

    @PostMapping("/command")
    public ResponseEntity<Void> sendCommand(
            Authentication authentication,
            @Valid @RequestBody DeviceCommandRequest request) {
        log.info("Sending command: {}", request);

        deviceManagementService.sendCommand(authentication.getName(), request);
        return ResponseEntity.accepted().build();
    }

    @PatchMapping("/{deviceId}/block")
    public ResponseEntity<Void> toggleBlock(
            Authentication authentication,
            @PathVariable String deviceId,
            @RequestParam boolean block) {
        log.info("Toggling device {} block to {}", deviceId, block);
        deviceManagementService.toggleDeviceBlock(authentication.getName(), deviceId, block);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/add")
    public ResponseEntity<DeviceResponse> addDevice(@Valid @RequestBody AddDeviceRequest request) {
        log.info("Adding device: {}", request);
        Device createdDevice = deviceManagementService.addDevice(request.uuid(), request);
        DeviceResponse response = new DeviceResponse(
                createdDevice.getId(),
                createdDevice.getDeviceId(),
                createdDevice.isBlocked(),
                createdDevice.getDeviceName()
        );
        log.info("Device added successfully: {}", response);

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping("/{deviceId}/alive")
    public ResponseEntity<Map<String, Boolean>> checkIsAlive(
            Authentication authentication,
            @PathVariable String deviceId) {
        log.info("Checking if device {} is alive", deviceId);

        boolean isAlive = deviceManagementService.isDeviceAlive(authentication.getName(), deviceId);
        return ResponseEntity.ok(Map.of("alive", isAlive));
    }

    @GetMapping("/{deviceId}/telemetry")
    public ResponseEntity<List<DeviceTelemetryPoint>> getDeviceTelemetry(
            Authentication authentication,
            @PathVariable String deviceId,
            @RequestParam(required = false, defaultValue = "-24h") String range) {
        log.info("Getting telemetry for device {} with range {}", deviceId, range);

        List<DeviceTelemetryPoint> telemetry = deviceManagementService.getDeviceTelemetry(
                authentication.getName(),
                deviceId,
                range
        );
        return ResponseEntity.ok(telemetry);
    }
}