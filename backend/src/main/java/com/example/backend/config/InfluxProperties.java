package com.example.backend.config;

import jakarta.validation.constraints.NotBlank;
import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "backend.influx")
@Getter
@Setter
public class InfluxProperties {
    @NotBlank
    private String host;

    @NotBlank
    private String token;

    @NotBlank
    private String bucket;

    @NotBlank
    private String org;
}
