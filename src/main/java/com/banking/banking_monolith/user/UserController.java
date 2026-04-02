package com.banking.banking_monolith.user;

import com.banking.banking_monolith.user.dto.RegisterRequest;
import com.banking.banking_monolith.user.dto.UpdateUserRequest;
import com.banking.banking_monolith.user.dto.UserResponse;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

// REST controller for user operations
// Register is public; get and update require a valid JWT token
@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
public class UserController {

    private final UserService userService;

    // Public endpoint - anyone can register
    @PostMapping("/register")
    public ResponseEntity<UserResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(userService.register(request));
    }

    // Returns user details by ID
    @GetMapping("/{id}")
    public ResponseEntity<UserResponse> getUser(@PathVariable Long id) {
        return ResponseEntity.ok(userService.getUserById(id));
    }

    // Updates first and last name for the given user ID
    @PutMapping("/{id}")
    public ResponseEntity<UserResponse> updateUser(@PathVariable Long id,
                                                    @Valid @RequestBody UpdateUserRequest request) {
        return ResponseEntity.ok(userService.updateUser(id, request));
    }
}
