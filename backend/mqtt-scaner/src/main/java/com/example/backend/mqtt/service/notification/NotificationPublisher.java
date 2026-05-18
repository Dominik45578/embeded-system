package com.example.backend.mqtt.service.notification;

import com.example.backend.mqtt.entity.Device;
import com.example.backend.mqtt.model.LockState;

public interface NotificationPublisher {
    void notifyStateChange(Device device, LockState lockState);
}