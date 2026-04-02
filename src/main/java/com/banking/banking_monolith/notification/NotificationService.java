package com.banking.banking_monolith.notification;

import com.banking.banking_monolith.exception.ResourceNotFoundException;
import com.banking.banking_monolith.notification.dto.NotificationResponse;
import com.banking.banking_monolith.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

// Handles all notification business logic
// Called directly by other services (no message queue - monolith approach)
@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;

    // Creates and saves a new notification for the given user
    @Async
    public void createNotification(User user, String message, NotificationType type) {
        Notification notification = Notification.builder()
                .user(user)
                .message(message)
                .type(type)
                .build();
        notificationRepository.save(notification);
    }

    // Returns all notifications for the user, newest first
    public List<NotificationResponse> getUserNotifications(Long userId) {
        return notificationRepository.findByUserIdOrderByCreatedAtDesc(userId)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    // Returns only unread notifications for the user
    public List<NotificationResponse> getUnreadNotifications(Long userId) {
        return notificationRepository.findByUserIdAndIsReadFalse(userId)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    // Marks a single notification as read - verifies the notification belongs to the requesting user
    public void markAsRead(Long notificationId, Long userId) {
        Notification notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new ResourceNotFoundException("Notification not found: " + notificationId));
        if (!notification.getUser().getId().equals(userId)) {
            throw new ResourceNotFoundException("Notification not found for this user");
        }
        notification.setRead(true);
        notificationRepository.save(notification);
    }

    // Converts Notification entity to NotificationResponse DTO
    private NotificationResponse toResponse(Notification n) {
        return NotificationResponse.builder()
                .id(n.getId())
                .userId(n.getUser().getId())
                .message(n.getMessage())
                .type(n.getType())
                .isRead(n.isRead())
                .createdAt(n.getCreatedAt())
                .build();
    }
}
