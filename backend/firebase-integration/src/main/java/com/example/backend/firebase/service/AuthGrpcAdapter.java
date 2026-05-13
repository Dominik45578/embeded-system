package com.example.backend.firebase.service;

import com.example.backend.common.auth.AuthServiceGrpc;
import com.example.backend.common.auth.AuthTokenResponse;
import com.example.backend.common.auth.VerifyTokenRequest;
import com.example.backend.firebase.dto.AuthTokenDto;
import com.example.backend.firebase.service.identity.FirebaseIdentityService;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.devh.boot.grpc.server.service.GrpcService;


@Slf4j
@GrpcService
@RequiredArgsConstructor
public class AuthGrpcAdapter extends AuthServiceGrpc.AuthServiceImplBase {

    private final FirebaseIdentityService firebaseIdentityService;

    @Override
    public void verifyToken(VerifyTokenRequest request, StreamObserver<AuthTokenResponse> responseObserver) {
        log.debug("Received gRPC request to verify token");
        try {
            String token = request.getToken();

            // 2. Delegacja do istniejącej logiki biznesowej
            AuthTokenDto authDto = firebaseIdentityService.verifyToken(token);

            // 3. Mapowanie DTO na obiekt odpowiedzi gRPC przy użyciu wygenerowanego Buildera
            AuthTokenResponse response = AuthTokenResponse.newBuilder()
                    .setUid(authDto.getUid())
                    .setEmail(authDto.getEmail() != null ? authDto.getEmail() : "")
                    .setName(authDto.getName() != null ? authDto.getName() : "")
                    .setPhotoUrl(authDto.getPhotoUrl() != null ? authDto.getPhotoUrl() : "")
                    .setIssuer(authDto.getIssuer() != null ? authDto.getIssuer() : "")
                    .build();

            responseObserver.onNext(response);
            responseObserver.onCompleted();

        } catch (Exception e) {
            log.error("Token verification failed in gRPC adapter", e);
            
            responseObserver.onError(Status.UNAUTHENTICATED
                    .withDescription("Invalid or expired Firebase token")
                    .withCause(e)
                    .asRuntimeException());
        }
    }
}