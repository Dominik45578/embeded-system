package com.example.backend.mqtt.model;

public enum LockState {
    IDLE_LOCKED,
    IDLE_STARTED,
    IDLE_KEEP_ALIVE,
    ENTERING_PIN,
    CHANGING_PIN,
    UNLOCKED,
    BLOCKED_TEMP,
    UNKNOWN
}
