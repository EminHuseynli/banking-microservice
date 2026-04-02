package com.banking.banking_monolith.account;

import com.banking.banking_monolith.account.dto.AccountResponse;
import com.banking.banking_monolith.account.dto.CreateAccountRequest;
import com.banking.banking_monolith.user.User;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// REST controller for account operations
// All endpoints require a valid JWT token - the logged-in user is injected via @AuthenticationPrincipal
@RestController
@RequestMapping("/api/accounts")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
public class AccountController {

    private final AccountService accountService;

    // Creates a new account for the currently logged-in user
    @PostMapping
    public ResponseEntity<AccountResponse> createAccount(@AuthenticationPrincipal User user,
                                                          @Valid @RequestBody CreateAccountRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(accountService.createAccount(user.getId(), request));
    }

    // Returns all accounts belonging to the currently logged-in user
    @GetMapping
    public ResponseEntity<List<AccountResponse>> getUserAccounts(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(accountService.getUserAccounts(user.getId()));
    }

    // Returns balance and details for a specific account - only accessible by the owner
    @GetMapping("/{id}/balance")
    public ResponseEntity<AccountResponse> getBalance(@PathVariable Long id,
                                                       @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(accountService.getBalance(id, user.getId()));
    }

    // Closes the account - only the owner can close their own account
    @DeleteMapping("/{id}")
    public ResponseEntity<AccountResponse> closeAccount(@PathVariable Long id,
                                                         @AuthenticationPrincipal User user) {
        return ResponseEntity.ok(accountService.closeAccount(id, user.getId()));
    }
}
