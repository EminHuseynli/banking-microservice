package com.banking.banking_monolith.notification.dto;

import com.banking.banking_monolith.notification.NotificationType;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class NotificationResponse {
    private Long id;
    private Long userId;
    private String message;
    private NotificationType type;
    private boolean isRead;
    private LocalDateTime createdAt;
}
