package com.example.backend.mqtt.service.device;

import com.example.backend.mqtt.dto.request.LockLogRequest;

public interface DeviceLogProcessingService {
    void processDeviceLog(LockLogRequest request) ;
}
