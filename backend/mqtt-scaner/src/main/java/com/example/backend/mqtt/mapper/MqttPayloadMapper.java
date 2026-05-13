package com.example.backend.mqtt.mapper;

import com.example.backend.mqtt.dto.response.LockCommandResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.ReportingPolicy;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface MqttPayloadMapper {

    @Mapping(target = "command", source = "command")
    @Mapping(target = "timestamp", expression = "java(java.time.Instant.now())")
    LockCommandResponse toCommandResponse(String command);
}