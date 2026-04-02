package com.banking.banking_monolith.account.dto;

import com.banking.banking_monolith.account.AccountStatus;
import com.banking.banking_monolith.account.AccountType;
import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
public class AccountResponse {
    private Long id;
    private String accountNumber;
    private AccountType accountType;
    private BigDecimal balance;
    private AccountStatus status;
    private Long userId;
    private String firstName;
    private String lastName;
    private LocalDateTime createdAt;
}
