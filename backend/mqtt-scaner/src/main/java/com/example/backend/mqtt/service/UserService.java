package com.example.backend.mqtt.service;

import com.example.backend.mqtt.entity.User;

public interface UserService {
    User synchronizeUser(String token);
    void updateFcmToken(String firebaseId, String fcmToken);
}