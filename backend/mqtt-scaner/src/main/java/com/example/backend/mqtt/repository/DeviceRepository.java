package com.example.backend.mqtt.repository;

import com.example.backend.mqtt.entity.Device;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface DeviceRepository extends JpaRepository<Device, Long> {

    @EntityGraph(attributePaths = {"user"})
    Optional<Device> findByDeviceId(String deviceId);
}