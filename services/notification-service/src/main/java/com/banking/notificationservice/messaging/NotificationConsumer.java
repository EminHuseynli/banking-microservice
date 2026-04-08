package com.banking.notificationservice.messaging;

import com.banking.notificationservice.notification.Notification;
import com.banking.notificationservice.notification.NotificationRepository;
import com.banking.notificationservice.notification.NotificationType;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class NotificationConsumer {

    private final NotificationRepository notificationRepository;

    @RabbitListener(queues = RabbitMQConfig.NOTIFICATION_QUEUE)
    public void consume(NotificationEvent event) {
        log.debug("Received notification event for userId={}", event.getUserId());

        NotificationType type;
        try {
            type = NotificationType.valueOf(event.getType());
        } catch (IllegalArgumentException e) {
            type = NotificationType.SYSTEM;
        }

        notificationRepository.save(Notification.builder()
                .userId(event.getUserId())
                .message(event.getMessage())
                .type(type)
                .build());
    }
}
