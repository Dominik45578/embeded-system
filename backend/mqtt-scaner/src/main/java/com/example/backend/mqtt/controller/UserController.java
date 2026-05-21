package com.example.backend.mqtt.controller;

import com.example.backend.mqtt.dto.request.FcmTokenRequest;
import com.example.backend.mqtt.dto.request.UserSyncRequest;
import com.example.backend.mqtt.entity.User;
import com.example.backend.mqtt.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    @PostMapping("/sync")
    public ResponseEntity<User> synchronizeUser(@Valid @RequestBody UserSyncRequest request) {
        log.info("Synchronizing user with token: {}", request.token());
        User user = userService.synchronizeUser(request.token());
        return ResponseEntity.status(HttpStatus.OK).body(user);
    }

    @PutMapping("/fcm-token")
    public ResponseEntity<Void> updateFcmToken(
            Authentication authentication,
            @Valid @RequestBody FcmTokenRequest request) {
        log.info("Updating FCM token for user: {}", authentication.getName());
        userService.updateFcmToken(authentication.getName(), request.fcmToken());
        return ResponseEntity.noContent().build();
    }
}