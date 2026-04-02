package com.banking.banking_monolith.exception;

// Thrown when a requested resource (user, account, notification) does not exist in the database
// Maps to HTTP 404 in GlobalExceptionHandler
public class ResourceNotFoundException extends RuntimeException {
    public ResourceNotFoundException(String message) {
        super(message);
    }
}
