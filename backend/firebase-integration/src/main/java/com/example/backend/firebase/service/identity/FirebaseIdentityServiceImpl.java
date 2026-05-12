package com.example.backend.firebase.service.identity;

import com.example.backend.firebase.dto.AuthTokenDto;
import com.example.backend.firebase.dto.UserRecordDto;
import com.example.backend.firebase.exceptions.InvalidTokenException;
import com.example.backend.firebase.exceptions.InvalidUserException;
import com.example.backend.firebase.mappers.FirebaseTokenMapper;
import com.example.backend.firebase.mappers.FirebaseUserMapper;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
@RequiredArgsConstructor
public class FirebaseIdentityServiceImpl implements FirebaseIdentityService {
    private final FirebaseAuth firebaseAuth;
    private final FirebaseTokenMapper firebaseTokenMapper;
    private final FirebaseUserMapper firebaseUserMapper;

    @Override
    public AuthTokenDto verifyToken(String token) {
        try {
            return  firebaseTokenMapper.toDto(firebaseAuth.verifyIdToken(token));
        } catch (FirebaseAuthException e) {
            log.debug("Invalid firebase token");
            throw new InvalidTokenException();
        }
    }

    @Override
    public UserRecordDto getUser(String uuid) {
        try {
            return firebaseUserMapper.toDto(firebaseAuth.getUser(uuid));
        } catch (FirebaseAuthException e) {
            throw new InvalidUserException();
        }
    }
}
