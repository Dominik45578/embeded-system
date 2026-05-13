package com.example.backend.mqtt.service;


import com.example.backend.common.auth.AuthServiceGrpc;
import com.example.backend.common.auth.AuthTokenResponse;
import com.example.backend.common.auth.VerifyTokenRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class TokenVerificationService {

    private final AuthServiceGrpc.AuthServiceBlockingStub authStub;

    public void verify(String token) {
        try {
            VerifyTokenRequest request = VerifyTokenRequest.newBuilder()
                    .setToken(token)
                    .build();

            AuthTokenResponse response = authStub.verifyToken(request);
            log.info("Token zweryfikowany dla użytkownika: {}", response.getEmail());
        } catch (Exception e) {
            log.error("Błąd weryfikacji gRPC: {}", e.getMessage());
            throw new RuntimeException("Nieautoryzowany dostęp");
        }
    }
}