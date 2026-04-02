package com.banking.banking_monolith.user;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

// Database access for User entity
public interface UserRepository extends JpaRepository<User, Long> {

    // Used during login to find the user by email
    Optional<User> findByEmail(String email);

    // Used during registration to check if email is already taken
    boolean existsByEmail(String email);
}
