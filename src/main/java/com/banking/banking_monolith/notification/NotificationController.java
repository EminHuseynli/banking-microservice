package com.banking.banking_monolith.notification;

import com.banking.banking_monolith.notification.dto.NotificationResponse;
import com.banking.banking_monolith.user.User;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

// REST controller for notification operations
// All endpoints require a valid JWT token
@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
public class NotificationController {

    private final NotificationService notificationService;

    // Returns all notifications for the currently logged-in user
    @GetMapping
    public ResponseEntity<List<NotificationResponse>> getNotifications(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(notificationService.getUserNotifications(user.getId()));
    }

    // Returns only unread notifications for the currently logged-in user
    @GetMapping("/unread")
    public ResponseEntity<List<NotificationResponse>> getUnread(@AuthenticationPrincipal User user) {
        return ResponseEntity.ok(notificationService.getUnreadNotifications(user.getId()));
    }

    // Marks a specific notification as read - returns 204 No Content on success
    @PatchMapping("/{id}/read")
    public ResponseEntity<Void> markAsRead(@PathVariable Long id, @AuthenticationPrincipal User user) {
        notificationService.markAsRead(id, user.getId());
        return ResponseEntity.noContent().build();
    }
}
