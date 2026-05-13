package com.example.backend.firebase.service.push;

import com.example.backend.firebase.model.StateChangeNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class FirebasePushNotificationService implements PushNotificationService {

    @Override
    public void sendLockStateNotification(StateChangeNotification notification) {
        //placeholder - muszę dodać kilka rzeczy
        String userTopic = "user_" + notification.userFirebaseId();

        Notification push = Notification.builder()
                .setTitle("Status zamka zmieniony")
                .setBody("Urządzenie " + notification.deviceId() + " zmieniło stan na: " + notification.lockState())
                .build();

        Message message = Message.builder()
                .setTopic(userTopic)
                .setNotification(push)
                .putData("deviceId", notification.deviceId())
                .putData("timestamp", notification.timestamp().toString())
                .build();

        try {
            String response = FirebaseMessaging.getInstance().send(message);
            log.info("Successfully sent Firebase notification: {}", response);
        } catch (Exception e) {
            log.error("Failed to send Firebase notification for user {}", notification.userFirebaseId(), e);
        }
    }
}