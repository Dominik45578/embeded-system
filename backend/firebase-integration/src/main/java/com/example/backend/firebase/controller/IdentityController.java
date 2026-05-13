package com.example.backend.firebase.controller;

import com.example.backend.firebase.dto.AuthTokenDto;
import com.example.backend.firebase.dto.UserRecordDto;
import com.example.backend.firebase.model.VerifyTokenRequest;
import com.example.backend.firebase.service.identity.FirebaseIdentityService;
import lombok.AllArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@AllArgsConstructor
@RequestMapping("user/")
public class IdentityController {
    private final FirebaseIdentityService firebaseIdentityService;

    @GetMapping("{uuid}")
    public ResponseEntity<UserRecordDto> getIdentity(@PathVariable String uuid){
        log.info("Get identity for user with uuid {}", uuid);
        UserRecordDto userRecordDto = firebaseIdentityService.getUser(uuid);
        log.info("Response: {}", userRecordDto);
      return ResponseEntity.ok(userRecordDto);
    }

    @PostMapping("/auth")
    public ResponseEntity<AuthTokenDto> verifyToken(@RequestBody VerifyTokenRequest request) {
        log.info("Verify auth token for user {}", request.idToken());
        AuthTokenDto authTokenDto = firebaseIdentityService.verifyToken(request.idToken());
        log.info("Response from auth token is {}", authTokenDto);
        return ResponseEntity.ok(authTokenDto);
    }
}
