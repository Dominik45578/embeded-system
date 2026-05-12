package com.example.backend.firebase.service.identity;

import com.example.backend.firebase.dto.AuthTokenDto;
import com.example.backend.firebase.dto.UserRecordDto;

public interface FirebaseIdentityService {
    UserRecordDto getUser(String uuid);
    AuthTokenDto verifyToken(String token);
}
