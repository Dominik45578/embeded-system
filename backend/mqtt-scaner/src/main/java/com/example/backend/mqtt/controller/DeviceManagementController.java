package com.example.backend.mqtt.controller;

import com.example.backend.mqtt.dto.request.AddDeviceRequest;
import com.example.backend.mqtt.dto.request.DeviceCommandRequest;
import com.example.backend.mqtt.entity.Device;
import com.example.backend.mqtt.service.device.DeviceManagementService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/devices")
@RequiredArgsConstructor
public class DeviceManagementController {

    private final DeviceManagementService deviceManagementService;

    @GetMapping
    public ResponseEntity<List<Device>> getMyDevices(Authentication authentication) {
        return ResponseEntity.ok(deviceManagementService.getUserDevices(authentication.getName()));
    }

    @PostMapping("/command")
    public ResponseEntity<Void> sendCommand(
            Authentication authentication,
            @Valid @RequestBody DeviceCommandRequest request) {
        
        deviceManagementService.sendCommand(authentication.getName(), request);
        return ResponseEntity.accepted().build();
    }

    @PatchMapping("/{deviceId}/block")
    public ResponseEntity<Void> toggleBlock(
            Authentication authentication,
            @PathVariable String deviceId,
            @RequestParam boolean block) {
        
        deviceManagementService.toggleDeviceBlock(authentication.getName(), deviceId, block);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/add")
    public ResponseEntity<Device> addDevice(@Valid @RequestBody AddDeviceRequest request) {
        Device createdDevice = deviceManagementService.addDevice(request.uuid(), request);
        return ResponseEntity.status(HttpStatus.CREATED).body(createdDevice);
    }
}