package com.example.backend.mqtt.config.channels;

import com.example.backend.common.auth.AuthServiceGrpc;
import net.devh.boot.grpc.client.inject.GrpcClient;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class GrpcClientConfig {

    @GrpcClient("firebase-auth")
    private AuthServiceGrpc.AuthServiceBlockingStub authServiceBlockingStub;

    @Bean
    public AuthServiceGrpc.AuthServiceBlockingStub authServiceBlockingStub() {
        return authServiceBlockingStub;
    }
}