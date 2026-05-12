package com.example.backend.firebase.mappers;

import com.example.backend.firebase.dto.AuthTokenDto;
import com.google.firebase.auth.FirebaseToken;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.ReportingPolicy;

@Mapper(componentModel = "spring", unmappedTargetPolicy = ReportingPolicy.IGNORE)
public interface FirebaseTokenMapper {

    @Mapping(source = "uid", target = "uid")
    @Mapping(source = "email", target = "email")
    @Mapping(source = "name", target = "name")
    @Mapping(source = "picture", target = "photoUrl")
    @Mapping(source = "claims", target = "allClaims")
    @Mapping(source = "issuer", target = "issuer")
    AuthTokenDto toDto(FirebaseToken token);
}
