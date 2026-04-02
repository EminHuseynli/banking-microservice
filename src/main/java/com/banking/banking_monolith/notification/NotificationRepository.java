package com.banking.banking_monolith.notification;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

// Database access for Notification entity
public interface NotificationRepository extends JpaRepository<Notification, Long> {

    // Returns all notifications for a user ordered by creation time (newest first)
    List<Notification> findByUserIdOrderByCreatedAtDesc(Long userId);

    // Returns only unread notifications for a user
    List<Notification> findByUserIdAndIsReadFalse(Long userId);
}
