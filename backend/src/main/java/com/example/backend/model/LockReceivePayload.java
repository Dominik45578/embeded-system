package com.example.backend.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;

public record LockReceivePayload(@NotBlank String deviceId, @NotNull LockState lockState, @NotNull Instant timestamp) {
}
