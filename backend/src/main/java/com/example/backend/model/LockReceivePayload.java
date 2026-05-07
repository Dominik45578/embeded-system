package com.example.backend.model;

import java.time.Instant;

public record LockReceivePayload(String deviceId, LockState lockState, Instant timestamp) {
}
