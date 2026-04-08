package com.banking.notificationservice.messaging;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

// Received from RabbitMQ — published by transaction-service after every transaction.
@Data
@NoArgsConstructor
@AllArgsConstructor
public class NotificationEvent {
    private Long userId;
    private String message;
    private String type;
}
