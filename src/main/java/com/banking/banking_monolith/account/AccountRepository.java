package com.banking.banking_monolith.account;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

// Database access for Account entity
public interface AccountRepository extends JpaRepository<Account, Long> {

    // Returns all accounts owned by the given user
    List<Account> findByUserId(Long userId);
}
