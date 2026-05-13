package com.example.backend.firebase.service.push;


import com.example.backend.firebase.model.StateChangeNotification;

public interface PushNotificationService {
    void sendLockStateNotification(StateChangeNotification notification);
}