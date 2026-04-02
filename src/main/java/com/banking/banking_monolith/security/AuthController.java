package com.banking.banking_monolith.security;

import com.banking.banking_monolith.user.User;
import com.banking.banking_monolith.user.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.web.bind.annotation.*;

// Public REST controller for authentication
// This is the only way to get a JWT token
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final UserService userService;

    // Validates email and password, then returns a JWT token along with email and role
    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        // Throws an exception if credentials are invalid
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getEmail(), request.getPassword())
        );

        User user = (User) userService.loadUserByUsername(request.getEmail());
        String token = jwtUtil.generateToken(user);

        return ResponseEntity.ok(new LoginResponse(token, user.getEmail(), user.getRole().name()));
    }
}
