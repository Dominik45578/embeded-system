package com.example.backend.mqtt;

import com.example.backend.mqtt.model.LockState;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CompletableFuture;

@Component
public class DevicePingManager {

    private final Map<String, CompletableFuture<Boolean>> pendingPings = new ConcurrentHashMap<>();

    public CompletableFuture<Boolean> registerPing(String deviceId) {
        CompletableFuture<Boolean> future = new CompletableFuture<>();
        pendingPings.put(deviceId, future);
        return future;
    }

    public void completePing(String deviceId, LockState lockState) {
        CompletableFuture<Boolean> future = pendingPings.get(deviceId);
        if (future != null) {
            if (lockState == LockState.IDLE_KEEP_ALIVE) {
                future.complete(true);
            }
        }
    }

    public void removePing(String deviceId) {
        pendingPings.remove(deviceId);
    }
}