package com.example.backend.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public record LockReceivePayload(
		@NotBlank
		@Size(min = 3, max = 64)
		@Pattern(regexp = "^[A-Za-z0-9_-]+$", message = "must contain only letters, numbers, underscores, or hyphens")
		String deviceId,
		@NotNull LockState lockState,
		@NotNull @PastOrPresent Instant timestamp
) {
}
