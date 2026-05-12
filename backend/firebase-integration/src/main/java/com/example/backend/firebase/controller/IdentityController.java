package com.example.backend.firebase.controller;

import com.example.backend.firebase.dto.AuthTokenDto;
import com.example.backend.firebase.dto.UserRecordDto;
import com.example.backend.firebase.service.identity.FirebaseIdentityService;
import lombok.AllArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@AllArgsConstructor
@RequestMapping("user/")
public class IdentityController {
    private final FirebaseIdentityService firebaseIdentityService;

    @GetMapping("{uuid}")
    public ResponseEntity<UserRecordDto> getIdentity(@PathVariable String uuid){
      return ResponseEntity.ok(firebaseIdentityService.getUser(uuid));
    }

    @PostMapping("/auth")
    public ResponseEntity<AuthTokenDto> verifyToken(@RequestBody String idToken) {
        return ResponseEntity.ok(firebaseIdentityService.verifyToken(idToken));
    }
}
