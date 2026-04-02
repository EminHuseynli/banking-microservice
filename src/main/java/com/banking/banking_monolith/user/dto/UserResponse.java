package com.banking.banking_monolith.user.dto;

import com.banking.banking_monolith.user.UserRole;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class UserResponse {
    private Long id;
    private String firstName;
    private String lastName;
    private String email;
    private UserRole role;
    private LocalDateTime createdAt;
}
