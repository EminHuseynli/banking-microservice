package com.banking.banking_monolith.account;

import com.banking.banking_monolith.account.dto.AccountResponse;
import com.banking.banking_monolith.account.dto.CreateAccountRequest;
import com.banking.banking_monolith.exception.AccountNotActiveException;
import com.banking.banking_monolith.exception.ResourceNotFoundException;
import com.banking.banking_monolith.notification.NotificationService;
import com.banking.banking_monolith.notification.NotificationType;
import com.banking.banking_monolith.user.User;
import com.banking.banking_monolith.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

// Handles all account-related business logic
@Service
@RequiredArgsConstructor
public class AccountService {

    private final AccountRepository accountRepository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    // Creates a new account for the given user with zero balance and sends a notification
    // Account number is derived from the DB-generated ID to avoid race conditions
    public AccountResponse createAccount(Long userId, CreateAccountRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));

        Account account = Account.builder()
                .accountNumber("PENDING")
                .accountType(request.getAccountType())
                .balance(BigDecimal.ZERO)
                .status(AccountStatus.ACTIVE)
                .user(user)
                .build();

        Account saved = accountRepository.save(account);
        saved.setAccountNumber(String.format("ACC-%06d", saved.getId()));
        saved = accountRepository.save(saved);

        notificationService.createNotification(user,
                "Your new account has been opened: " + saved.getAccountNumber(), NotificationType.SYSTEM);

        return toResponse(saved);
    }

    // Returns the balance and details of a specific account - only the owner can access it
    public AccountResponse getBalance(Long accountId, Long userId) {
        Account account = findByIdAndUser(accountId, userId);
        return toResponse(account);
    }

    // Returns all accounts belonging to the given user
    public List<AccountResponse> getUserAccounts(Long userId) {
        return accountRepository.findByUserId(userId)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    // Closes an account by setting its status to CLOSED - only the owner can close it
    public AccountResponse closeAccount(Long accountId, Long userId) {
        Account account = findByIdAndUser(accountId, userId);
        account.setStatus(AccountStatus.CLOSED);
        return toResponse(accountRepository.save(account));
    }

    // Used by TransactionService to verify an account is active before processing transactions
    public Account getActiveAccount(Long accountId) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new ResourceNotFoundException("Account not found: " + accountId));
        if (account.getStatus() != AccountStatus.ACTIVE) {
            throw new AccountNotActiveException("Account is not active: " + accountId);
        }
        return account;
    }

    // Finds an account by ID and verifies it belongs to the given user
    private Account findByIdAndUser(Long accountId, Long userId) {
        Account account = accountRepository.findById(accountId)
                .orElseThrow(() -> new ResourceNotFoundException("Account not found: " + accountId));
        if (!account.getUser().getId().equals(userId)) {
            throw new ResourceNotFoundException("Account not found for this user");
        }
        return account;
    }

    // Converts Account entity to AccountResponse DTO
    private AccountResponse toResponse(Account account) {
        return AccountResponse.builder()
                .id(account.getId())
                .accountNumber(account.getAccountNumber())
                .accountType(account.getAccountType())
                .balance(account.getBalance())
                .status(account.getStatus())
                .userId(account.getUser().getId())
                .firstName(account.getUser().getFirstName())
                .lastName(account.getUser().getLastName())
                .createdAt(account.getCreatedAt())
                .build();
    }
}
