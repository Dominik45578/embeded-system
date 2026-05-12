package com.example.backend.firebase.config;

import com.example.backend.firebase.exceptions.InvalidTokenException;
import com.example.backend.firebase.exceptions.InvalidUserException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
@Slf4j
@RestControllerAdvice
public class GlobalExceptionAdviser {

    @ExceptionHandler(InvalidTokenException.class)
    public ProblemDetail handleInvalidToken(InvalidTokenException ex) {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.UNAUTHORIZED,
                ex.getMessage()
        );

        problemDetail.setTitle("Błąd autoryzacji");
        problemDetail.setProperty("timestamp", Instant.now());

        return problemDetail;
    }

    @ExceptionHandler(InvalidUserException.class)
    public ProblemDetail handleInvalidUser(InvalidUserException ex) {
        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.NOT_FOUND,
                ex.getMessage()
        );

        problemDetail.setTitle("Użytkownik nie istnieje");
        problemDetail.setProperty("timestamp", Instant.now());

        return problemDetail;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleAllRemainingExceptions(Exception ex) {
        log.error("Wystąpił nieoczekiwany błąd systemowy: ", ex);

        ProblemDetail problemDetail = ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Wystąpił wewnętrzny błąd serwera. Spróbuj ponownie później."
        );
        problemDetail.setTitle("Błąd systemowy");
        problemDetail.setProperty("timestamp", Instant.now());

        return problemDetail;
    }
}