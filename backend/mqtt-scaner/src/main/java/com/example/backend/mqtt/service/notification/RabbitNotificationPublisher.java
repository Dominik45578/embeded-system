package com.example.backend.mqtt.service.notification;

import com.example.backend.mqtt.config.channels.RabbitMQConfig;
import com.example.backend.mqtt.entity.Device;
import com.example.backend.mqtt.model.LockState;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
@RequiredArgsConstructor
@Slf4j
class RabbitNotificationPublisher implements NotificationPublisher {

    private final RabbitTemplate rabbitTemplate;

    @Override
    public void notifyStateChange(Device device, LockState lockState) {
        var payload = new StateChangeNotification(
                device.getDeviceId(),
                device.getUser().getFirebaseId(),
                device.getUser().getFcmToken(),
                lockState,
                Instant.now()
        );

        log.debug("Publishing JSON state change to RabbitMQ for device {}", device.getDeviceId());
        
        rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE_LOCK,
                RabbitMQConfig.ROUTING_KEY_LOCK_STATE,
                payload
        );
    }

    // DTO proper JSON serialization mate
    public record StateChangeNotification(
            String deviceId,
            String userFirebaseId,
            String fcmToken,
            LockState lockState,
            Instant timestamp
    ) {}
}