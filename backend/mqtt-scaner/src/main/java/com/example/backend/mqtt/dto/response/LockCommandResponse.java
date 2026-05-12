package com.example.backend.mqtt.dto.response;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public record LockCommandResponse(
        @NotBlank
        Instant timestamp,
        @NotBlank @Size(min = 1, max = 1024) String command
) { }
