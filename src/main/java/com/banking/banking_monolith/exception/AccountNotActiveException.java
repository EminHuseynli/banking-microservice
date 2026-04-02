package com.banking.banking_monolith.exception;

// Thrown when a transaction is attempted on a closed account
// Maps to HTTP 400 in GlobalExceptionHandler
public class AccountNotActiveException extends RuntimeException {
    public AccountNotActiveException(String message) {
        super(message);
    }
}
