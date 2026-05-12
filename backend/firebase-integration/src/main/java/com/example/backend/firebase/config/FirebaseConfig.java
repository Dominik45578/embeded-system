package com.example.backend.firebase.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.FileInputStream;

@Slf4j
@Configuration
public class FirebaseConfig {

    @Value("${firebase.key.path}")
    private String firebaseKeyPath;

    @PostConstruct
    public void init() throws Exception {

        if (!FirebaseApp.getApps().isEmpty()) {
            log.info("Firebase App has been initialized");
            return;
        }

        FileInputStream serviceAccount =
                new FileInputStream(firebaseKeyPath);

        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                .build();

//        FirebaseOptions options = FirebaseOptions.builder()
//                .setCredentials(GoogleCredentials.getApplicationDefault())
//                .build();


        FirebaseApp.initializeApp(options);

        log.info("Firebase initialized successfully");
    }

    @Bean
    public FirebaseAuth firebaseAuth() {
        return FirebaseAuth.getInstance();
    }
}