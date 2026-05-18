package com.example.backend.mqtt.service.device;

import com.example.backend.mqtt.dto.request.AddDeviceRequest;
import com.example.backend.mqtt.dto.request.DeviceCommandRequest;
import com.example.backend.mqtt.dto.response.LockCommandResponse;
import com.example.backend.mqtt.entity.Device;
import com.example.backend.mqtt.entity.User;
import com.example.backend.mqtt.repository.DeviceRepository;
import com.example.backend.mqtt.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DeviceManagementServiceImpl implements DeviceManagementService {

    private final DeviceRepository deviceRepository;
    private final UserRepository userRepository;
    private final DeviceCommandMqttPublisher deviceCommandMqttPublisher;

    @Override
    public List<Device> getUserDevices(String firebaseId) {
        return userRepository.findById(firebaseId)
                .map(User::getDevices)
                .orElse(List.of());
    }
    @Override
    @Transactional
    public void sendCommand(String firebaseId, DeviceCommandRequest request) {
        Device device = verifyOwnership(firebaseId, request.getDeviceId());

        if (device.isBlocked()) {
            throw new IllegalStateException("Urządzenie jest zablokowane.");
        }

        LockCommandResponse response = new LockCommandResponse(Instant.now(), request.getCommand());
        deviceCommandMqttPublisher.sendCommand(device.getDeviceId(), response);
    }

    @Override
    @Transactional
    public void toggleDeviceBlock(String firebaseId, String deviceId, boolean block) {
        Device device = verifyOwnership(firebaseId, deviceId);
        device.setBlocked(block);
        deviceRepository.save(device);
    }

    private Device verifyOwnership(String firebaseId, String deviceId) {
        Device device = deviceRepository.findByDeviceId(deviceId)
                .orElseThrow(() -> new IllegalArgumentException("Nie znaleziono urządzenia."));

        if (!device.getUser().getFirebaseId().equals(firebaseId)) {
            throw new AccessDeniedException("Nie masz uprawnień do tego urządzenia.");
        }
        return device;
    }

    @Override
    @Transactional
    public Device addDevice(String firebaseId, AddDeviceRequest request) {
        User user = userRepository.findById(firebaseId)
                .orElseThrow(() -> new IllegalArgumentException("Użytkownik o podanym ID nie istnieje."));

        return deviceRepository.findByDeviceId(request.deviceId())
                .map(existingDevice -> {
                    if (existingDevice.getUser() != null) {
                        if (existingDevice.getUser().getFirebaseId().equals(firebaseId)) {
                            if (request.deviceName() != null && !request.deviceName().isBlank()) {
                                existingDevice.setDeviceName(request.deviceName());
                            }
                            return deviceRepository.save(existingDevice);
                        } else {
                            throw new IllegalStateException("Urządzenie o tym identyfikatorze jest już przypisane do innego użytkownika.");
                        }
                    }
                    existingDevice.setUser(user);
                    if (request.deviceName() != null && !request.deviceName().isBlank()) {
                        existingDevice.setDeviceName(request.deviceName());
                    }
                    return deviceRepository.save(existingDevice);
                })
                .orElseGet(() -> {
                    String name = (request.deviceName() != null && !request.deviceName().isBlank())
                            ? request.deviceName()
                            : "default_device";
                    Device newDevice = Device.builder()
                            .deviceId(request.deviceId())
                            .deviceName(name)
                            .blocked(false)
                            .user(user)
                            .build();

                    return deviceRepository.save(newDevice);
                });
    }
}