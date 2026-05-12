package com.example.backend.firebase.exceptions;

public class InvalidUserException extends RuntimeException {
    public InvalidUserException(String message) {
        super(message);
    }
    public InvalidUserException() {
        super("Invalid User");
    }
}
