package com.banking.banking_monolith.exception;

// Thrown when an account does not have enough balance for a withdrawal or transfer
// Maps to HTTP 400 in GlobalExceptionHandler
public class InsufficientFundsException extends RuntimeException {
    public InsufficientFundsException(String message) {
        super(message);
    }
}
