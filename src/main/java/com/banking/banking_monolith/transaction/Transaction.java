package com.banking.banking_monolith.transaction;

import com.banking.banking_monolith.account.Account;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

// Transaction entity - mapped to the "transactions" table in the database
// Records every deposit, withdrawal, and transfer
// Indexes on source and target account IDs to speed up transaction history queries
@Entity
@Table(name = "transactions", indexes = {
    @Index(name = "idx_source_account", columnList = "source_account_id"),
    @Index(name = "idx_target_account", columnList = "target_account_id")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Transaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // DEPOSIT, WITHDRAWAL, or TRANSFER
    @Enumerated(EnumType.STRING)
    @Column(name = "transaction_type", nullable = false)
    private TransactionType transactionType;

    // Stored with high precision to avoid rounding errors
    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;

    private String description;

    // SUCCESS or FAILED
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private TransactionStatus status;

    // The account the money comes from
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "source_account_id", nullable = false)
    private Account sourceAccount;

    // The account the money goes to - only used for TRANSFER, null for deposits/withdrawals
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_account_id")
    private Account targetAccount;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    // Automatically set creation time before saving to DB
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
