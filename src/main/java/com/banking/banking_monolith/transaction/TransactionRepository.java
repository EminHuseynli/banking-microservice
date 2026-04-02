package com.banking.banking_monolith.transaction;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

// Database access for Transaction entity
public interface TransactionRepository extends JpaRepository<Transaction, Long> {

    // Returns all transactions where the account is either the source or the target, newest first
    @Query("SELECT t FROM Transaction t WHERE t.sourceAccount.id = :accountId OR t.targetAccount.id = :accountId ORDER BY t.createdAt DESC")
    List<Transaction> findByAccountId(@Param("accountId") Long accountId);

    // Same as above but filtered by a date range
    @Query("SELECT t FROM Transaction t WHERE (t.sourceAccount.id = :accountId OR t.targetAccount.id = :accountId) AND t.createdAt BETWEEN :start AND :end ORDER BY t.createdAt DESC")
    List<Transaction> findByAccountIdAndDateRange(@Param("accountId") Long accountId,
                                                   @Param("start") LocalDateTime start,
                                                   @Param("end") LocalDateTime end);
}
