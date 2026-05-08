package com.example.backend.config;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

@ConfigurationProperties(prefix = "backend.mqtt")
@Validated
@Getter
@Setter
public class MqttProperties {
    @NotBlank
    private String host;

    @NotBlank
    private String topic;
}

