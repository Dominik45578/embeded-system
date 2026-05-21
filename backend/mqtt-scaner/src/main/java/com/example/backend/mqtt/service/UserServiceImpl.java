package com.example.backend.mqtt.service;

import com.example.backend.common.auth.AuthTokenResponse;
import com.example.backend.mqtt.entity.User;
import com.example.backend.mqtt.repository.UserRepository;
import com.example.backend.mqtt.service.TokenVerificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserServiceImpl implements UserService {

    private final UserRepository userRepository;
    private final TokenVerificationService tokenVerificationService;

    @Override
    @Transactional
    public User synchronizeUser(String token) {
        AuthTokenResponse authData = tokenVerificationService.verify(token);
        return userRepository.findById(authData.getUid())
                .orElseGet(() -> {
                    User newUser = User.builder()
                            .firebaseId(authData.getUid())
                            .email(authData.getEmail())
                            .build();
                    return userRepository.save(newUser);
                });
    }
    @Override
    @Transactional
    public void updateFcmToken(String firebaseId, String fcmToken) {
        User user = userRepository.findById(firebaseId)
                .orElseThrow(() -> new IllegalArgumentException("Użytkownik o podanym ID nie istnieje."));
        user.setFcmToken(fcmToken);
        userRepository.save(user);
    }
}