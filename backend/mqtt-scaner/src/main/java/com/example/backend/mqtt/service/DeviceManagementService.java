package com.example.backend.mqtt.service;

import com.example.backend.mqtt.dto.request.DeviceCommandRequest;
import com.example.backend.mqtt.entity.Device;
import java.util.List;

public interface DeviceManagementService {
    List<Device> getUserDevices(String firebaseId);
    void sendCommand(String firebaseId, DeviceCommandRequest request);
    void toggleDeviceBlock(String firebaseId, String deviceId, boolean block);
}