package com.example.backend.mqtt.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class DeviceCommandRequest {
    @NotBlank
    private String deviceId;
    
    @NotBlank
    private String command;
}