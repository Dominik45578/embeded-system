package com.example.backend.firebase.model;

import java.time.Instant;

public record StateChangeNotification(
        String deviceId,
        String userFirebaseId,
        String lockState,
        Instant timestamp
) {}