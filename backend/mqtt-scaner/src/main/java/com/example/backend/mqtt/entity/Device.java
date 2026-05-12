package com.example.backend.mqtt.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Entity
@Table(name = "devices")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "device_id", unique = true, nullable = false)
    private String deviceId;

    @Builder.Default
    @Column(nullable = false)
    private boolean blocked = false;

    @Column(nullable = false)
    @Builder.Default
    private String deviceName = "default_device";

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_firebase_id")
    private User user;
}