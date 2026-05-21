package com.example.backend.mqtt.dto.request;


import com.example.backend.mqtt.model.LockState;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.validation.annotation.Validated;

import java.time.Instant;

@Validated
public record LockLogRequest(
        @NotBlank
        @Size(min = 3, max = 64)
        @Pattern(regexp = "^[A-Za-z0-9_-]+$", message = "must contain only letters, numbers, underscores, or hyphens")
        String deviceId,
        @NotNull Instant timestamp,
        @NotBlank @Size(min = 1, max = 1024) String message,
        @NotNull LockState lockState,

        @NotBlank @Size(min = 4, max = 32) String source
) {

}
