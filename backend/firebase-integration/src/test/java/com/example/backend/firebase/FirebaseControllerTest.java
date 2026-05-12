package com.example.backend.firebase;

import com.example.backend.firebase.dto.AuthTokenDto;
import com.example.backend.firebase.mappers.FirebaseTokenMapper;
import com.example.backend.firebase.service.identity.FirebaseIdentityServiceImpl;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.boot.test.context.SpringBootTest;

import static org.assertj.core.api.AssertionsForClassTypes.assertThat;
import static org.mockito.Mockito.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ExtendWith(MockitoExtension.class)
public class FirebaseControllerTest {


    @Mock
    private FirebaseAuth firebaseAuth;

    @Mock
    private FirebaseTokenMapper firebaseTokenMapper;

    @InjectMocks
    private FirebaseIdentityServiceImpl firebaseIdentityService;

    @Test
    void shouldVerifyTokenAndReturnDto()
            throws FirebaseAuthException {

        // given

        FirebaseToken firebaseToken =
                mock(FirebaseToken.class);

        AuthTokenDto expectedDto =
                mock(AuthTokenDto.class);

        when(firebaseAuth.verifyIdToken("jwt-token"))
                .thenReturn(firebaseToken);

        when(firebaseTokenMapper.toDto(firebaseToken))
                .thenReturn(expectedDto);

        // when

        AuthTokenDto result =
                firebaseIdentityService.verifyToken("jwt-token");

        // then

        assertThat(result)
                .isEqualTo(expectedDto);

        verify(firebaseAuth)
                .verifyIdToken("jwt-token");

        verify(firebaseTokenMapper)
                .toDto(firebaseToken);
    }

}
