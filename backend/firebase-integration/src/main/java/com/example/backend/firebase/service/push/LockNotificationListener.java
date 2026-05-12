package com.example.backend.firebase.service.push;

import com.example.backend.firebase.config.RabbitMQConfig;
import com.example.backend.firebase.model.StateChangeNotification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class LockNotificationListener {

    private final PushNotificationService pushNotificationService;

    @RabbitListener(queues = RabbitMQConfig.QUEUE_LOCK_STATE_CHANGE)
    public void handleLockStateChange(StateChangeNotification notification) {
        log.info("Received notification request from RabbitMQ for device: {}", notification.deviceId());
        pushNotificationService.sendLockStateNotification(notification);
    }
}