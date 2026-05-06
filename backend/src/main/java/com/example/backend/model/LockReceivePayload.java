package com.example.backend.model;

public record LockReceivePayload(String deviceId, LockState lockState) {
}
