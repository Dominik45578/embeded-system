package com.example.backend.firebase.mappers;

import com.example.backend.firebase.dto.UserRecordDto;
import com.google.firebase.auth.UserRecord;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.ReportingPolicy;

@Mapper(
    componentModel = "spring", 
    unmappedTargetPolicy = ReportingPolicy.IGNORE
)
public interface FirebaseUserMapper {
    @Mapping(source = "uid", target = "id")
    @Mapping(source = "displayName", target = "fullName")
    @Mapping(source = "photoUrl", target = "avatarUrl")
    @Mapping(source = "emailVerified", target = "emailConfirmed")
    @Mapping(target = "active", expression = "java(!userRecord.isDisabled())")
    @Mapping(source = "customClaims", target = "metadata")
    UserRecordDto toDto(UserRecord userRecord);
}