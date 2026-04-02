package com.banking.banking_monolith.account.dto;

import com.banking.banking_monolith.account.AccountType;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CreateAccountRequest {

    @NotNull(message = "Account type is required")
    private AccountType accountType;
}
