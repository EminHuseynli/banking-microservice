package com.banking.banking_monolith.transaction;

import com.banking.banking_monolith.transaction.dto.*;
import com.banking.banking_monolith.user.User;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

// REST controller for transaction operations
// All endpoints require a valid JWT token
@RestController
@RequestMapping("/api/transactions")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
public class TransactionController {

    private final TransactionService transactionService;

    // Deposits money into any active account - no ownership check
    @PostMapping("/deposit")
    public ResponseEntity<TransactionResponse> deposit(@Valid @RequestBody DepositRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(transactionService.deposit(request));
    }

    // Withdraws money - only the account owner can withdraw
    @PostMapping("/withdraw")
    public ResponseEntity<TransactionResponse> withdraw(@Valid @RequestBody WithdrawRequest request,
                                                        @AuthenticationPrincipal User user) {
        return ResponseEntity.status(HttpStatus.CREATED).body(transactionService.withdraw(request, user.getId()));
    }

    // Transfers money between accounts - only the source account owner can initiate
    @PostMapping("/transfer")
    public ResponseEntity<TransactionResponse> transfer(@Valid @RequestBody TransferRequest request,
                                                        @AuthenticationPrincipal User user) {
        return ResponseEntity.status(HttpStatus.CREATED).body(transactionService.transfer(request, user.getId()));
    }

    // Returns transaction history for an account
    // Optionally filter by date range using start and end query params (ISO format)
    @GetMapping("/{accountId}/history")
    public ResponseEntity<List<TransactionResponse>> getHistory(
            @PathVariable Long accountId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime start,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime end) {

        if (start != null && end != null) {
            return ResponseEntity.ok(transactionService.getAccountHistoryByDateRange(accountId, start, end));
        }
        return ResponseEntity.ok(transactionService.getAccountHistory(accountId));
    }
}
