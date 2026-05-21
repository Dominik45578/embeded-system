package com.example.backend.mqtt.service.device;

import com.example.backend.mqtt.dto.request.AddDeviceRequest;
import com.example.backend.mqtt.dto.request.DeviceCommandRequest;
import com.example.backend.mqtt.dto.response.DeviceResponse;
import com.example.backend.mqtt.entity.Device;
import com.example.backend.mqtt.model.DeviceTelemetryPoint;

import java.util.List;

public interface DeviceManagementService {
    List<DeviceResponse> getUserDevices(String firebaseId);
    void sendCommand(String firebaseId, DeviceCommandRequest request);
    void toggleDeviceBlock(String firebaseId, String deviceId, boolean block);
    Device addDevice(String firebaseId, AddDeviceRequest request);
    boolean isDeviceAlive(String firebaseId, String deviceId);
    List<DeviceTelemetryPoint> getDeviceTelemetry(String firebaseId, String deviceId, String range);
}