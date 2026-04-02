package com.banking.banking_monolith.notification;

import com.banking.banking_monolith.user.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

// Notification entity - mapped to the "notifications" table in the database
// Created automatically for events like registration, account opening, and transactions
@Entity
@Table(name = "notifications")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // The user who receives this notification
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String message;

    // TRANSACTION (deposit/withdraw/transfer) or SYSTEM (registration, account opened)
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private NotificationType type;

    @Column(name = "is_read", nullable = false)
    private boolean isRead;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    // Automatically set creation time and mark as unread before saving to DB
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        isRead = false;
    }
}
